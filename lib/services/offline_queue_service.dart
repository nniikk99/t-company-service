import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Очередь действий, выполненных пользователем без интернета.
///
/// Хранит JSON-массив pending operations в SharedPreferences под ключом
/// [_storageKey]. Слушает изменения connectivity и при появлении сети
/// автоматически прогоняет очередь в порядке создания.
///
/// Поддерживаемые типы операций:
///   - `service_request_status`  — обновление статуса service_requests
///   - `part_order_status`       — обновление статуса part_orders
///   - `service_request_field`   — обновление произвольного поля service_requests
///   - `part_order_field`        — обновление произвольного поля part_orders
///   - `request_message`         — отправка сообщения в чат заявки
///
/// API:
///   - [enqueue]  — добавить операцию (вызывается из репозиториев / UI)
///   - [flush]    — попытаться отправить все pending (можно вызвать вручную)
///   - [isOnline] — текущее состояние сети (стрим [onlineStream])
///   - [pendingCount] — сколько операций ждёт (стрим [pendingCountStream])
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const String _storageKey = 'offline_queue_v1';
  static const int _maxRetries = 5;

  final _client = Supabase.instance.client;
  final _connectivity = Connectivity();
  final _uuid = const Uuid();

  // ── Состояние ─────────────────────────────────────────────────────────

  final _onlineCtrl = StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _onlineCtrl.stream;
  bool _online = true;
  bool get isOnline => _online;

  final _pendingCtrl = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCtrl.stream;
  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  bool _flushing = false;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // ── Инициализация ─────────────────────────────────────────────────────

  Future<void> init() async {
    // Восстанавливаем текущий счётчик
    final list = await _readQueue();
    _pendingCount = list.length;
    _pendingCtrl.add(_pendingCount);

    // Текущее состояние сети
    final initial = await _connectivity.checkConnectivity();
    _online = _hasNetwork(initial);
    _onlineCtrl.add(_online);

    // Подписка
    _connSub = _connectivity.onConnectivityChanged.listen((results) async {
      final wasOnline = _online;
      _online = _hasNetwork(results);
      _onlineCtrl.add(_online);
      if (!wasOnline && _online) {
        // Сеть появилась — пробуем выгрузить очередь
        unawaited(flush());
      }
    });

    // Если стартовали онлайн и в очереди что-то есть — попробуем выгрузить сразу
    if (_online && _pendingCount > 0) {
      unawaited(flush());
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ── Публичный API ─────────────────────────────────────────────────────

  /// Добавить операцию в очередь. Возвращает её локальный id.
  /// Если онлайн — сразу пытается отправить (но в любом случае операция
  /// попадает в очередь, чтобы UI мог отображать pending-состояние).
  Future<String> enqueue(_PendingOp op) async {
    final list = await _readQueue();
    final stored = op.copyWithId(_uuid.v4());
    list.add(stored.toJson());
    await _writeQueue(list);
    _setCount(list.length);

    if (_online) {
      unawaited(flush());
    }
    return stored.id;
  }

  /// Прогоняет очередь по порядку. Прерывается при первом провале сети
  /// (чтобы остальные операции тоже не сожгли retry_count).
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (true) {
        final list = await _readQueue();
        if (list.isEmpty) break;
        final raw = list.first;
        final op = _PendingOp.fromJson(raw);

        bool ok;
        try {
          await _execute(op);
          ok = true;
        } on SocketException catch (_) {
          // Нет сети
          _online = false;
          _onlineCtrl.add(false);
          _scheduleRetry();
          break;
        } catch (e) {
          debugPrint('Offline queue: ошибка выполнения ${op.type}: $e');
          ok = false;
        }

        if (ok) {
          list.removeAt(0);
          await _writeQueue(list);
          _setCount(list.length);
        } else {
          // Повышаем retry_count
          final next = op.copyWithRetry(op.retryCount + 1);
          if (next.retryCount >= _maxRetries) {
            // Операция «сгорела» — удаляем, оставляем лог
            debugPrint(
                'Offline queue: ${op.type} (${op.id}) превышен лимит попыток, удаляем');
            list.removeAt(0);
          } else {
            list[0] = next.toJson();
          }
          await _writeQueue(list);
          _setCount(list.length);
          _scheduleRetry();
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// Получить операции по `requestId` (для UI: «эта заявка имеет N pending»).
  Future<List<_PendingOp>> pendingFor(String requestId) async {
    final list = await _readQueue();
    return list
        .map((j) => _PendingOp.fromJson(j))
        .where((op) => op.requestId == requestId)
        .toList();
  }

  /// Очистить всю очередь (для отладки)
  Future<void> clear() async {
    await _writeQueue(const []);
    _setCount(0);
  }

  // ── Внутреннее: исполнение операций ───────────────────────────────────

  Future<void> _execute(_PendingOp op) async {
    switch (op.type) {
      case _OpType.serviceRequestStatus:
        await _client
            .from('service_requests')
            .update({
              'status': op.payload['status'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', op.requestId);
        break;
      case _OpType.serviceRequestField:
        final update = Map<String, dynamic>.from(op.payload);
        update['updated_at'] = DateTime.now().toIso8601String();
        await _client
            .from('service_requests')
            .update(update)
            .eq('id', op.requestId);
        break;
      case _OpType.partOrderStatus:
        await _client
            .from('part_orders')
            .update({
              'status': op.payload['status'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', op.requestId);
        break;
      case _OpType.partOrderField:
        final update = Map<String, dynamic>.from(op.payload);
        update['updated_at'] = DateTime.now().toIso8601String();
        await _client
            .from('part_orders')
            .update(update)
            .eq('id', op.requestId);
        break;
      case _OpType.requestMessage:
        await _client.from('request_messages').insert({
          'request_id': op.requestId,
          'sender_id': op.payload['sender_id'],
          'message': op.payload['message'],
          'created_at': op.payload['created_at'] ??
              DateTime.now().toIso8601String(),
        });
        break;
    }
  }

  // ── Хелперы ───────────────────────────────────────────────────────────

  void _setCount(int n) {
    _pendingCount = n;
    _pendingCtrl.add(n);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 15), () {
      if (_online) unawaited(flush());
    });
  }

  Future<List<dynamic>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<dynamic> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  void dispose() {
    _connSub?.cancel();
    _retryTimer?.cancel();
    _onlineCtrl.close();
    _pendingCtrl.close();
  }
}

// ─── Типы операций ───────────────────────────────────────────────────────

enum _OpType {
  serviceRequestStatus,
  serviceRequestField,
  partOrderStatus,
  partOrderField,
  requestMessage,
}

extension _OpTypeStr on _OpType {
  String get key {
    switch (this) {
      case _OpType.serviceRequestStatus:
        return 'service_request_status';
      case _OpType.serviceRequestField:
        return 'service_request_field';
      case _OpType.partOrderStatus:
        return 'part_order_status';
      case _OpType.partOrderField:
        return 'part_order_field';
      case _OpType.requestMessage:
        return 'request_message';
    }
  }

  static _OpType? parse(String k) {
    for (final t in _OpType.values) {
      if (t.key == k) return t;
    }
    return null;
  }
}

class _PendingOp {
  final String id;
  final _OpType type;
  final String requestId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  const _PendingOp({
    required this.id,
    required this.type,
    required this.requestId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  _PendingOp copyWithId(String newId) => _PendingOp(
        id: newId,
        type: type,
        requestId: requestId,
        payload: payload,
        createdAt: createdAt,
        retryCount: retryCount,
      );

  _PendingOp copyWithRetry(int r) => _PendingOp(
        id: id,
        type: type,
        requestId: requestId,
        payload: payload,
        createdAt: createdAt,
        retryCount: r,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.key,
        'request_id': requestId,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
      };

  static _PendingOp fromJson(dynamic j) {
    final m = j as Map<String, dynamic>;
    return _PendingOp(
      id: m['id'] as String,
      type: _OpTypeStr.parse(m['type'] as String)!,
      requestId: m['request_id'] as String,
      payload: Map<String, dynamic>.from(m['payload'] as Map),
      createdAt: DateTime.parse(m['created_at'] as String),
      retryCount: (m['retry_count'] as int?) ?? 0,
    );
  }

  /// Удобные фабрики
  static _PendingOp serviceRequestStatus(
          {required String requestId, required String status}) =>
      _PendingOp(
        id: '',
        type: _OpType.serviceRequestStatus,
        requestId: requestId,
        payload: {'status': status},
        createdAt: DateTime.now(),
      );

  static _PendingOp partOrderStatus(
          {required String requestId, required String status}) =>
      _PendingOp(
        id: '',
        type: _OpType.partOrderStatus,
        requestId: requestId,
        payload: {'status': status},
        createdAt: DateTime.now(),
      );

  static _PendingOp serviceRequestField(
          {required String requestId,
          required Map<String, dynamic> fields}) =>
      _PendingOp(
        id: '',
        type: _OpType.serviceRequestField,
        requestId: requestId,
        payload: fields,
        createdAt: DateTime.now(),
      );

  static _PendingOp partOrderField(
          {required String requestId,
          required Map<String, dynamic> fields}) =>
      _PendingOp(
        id: '',
        type: _OpType.partOrderField,
        requestId: requestId,
        payload: fields,
        createdAt: DateTime.now(),
      );

  static _PendingOp requestMessage(
          {required String requestId,
          required String senderId,
          required String message}) =>
      _PendingOp(
        id: '',
        type: _OpType.requestMessage,
        requestId: requestId,
        payload: {
          'sender_id': senderId,
          'message': message,
          'created_at': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );
}

// Публичный wrapper над приватным классом для удобных вызовов.
class OfflineOp {
  OfflineOp._();

  static Future<String> serviceRequestStatus({
    required String requestId,
    required String status,
  }) =>
      OfflineQueueService.instance.enqueue(
        _PendingOp.serviceRequestStatus(
            requestId: requestId, status: status),
      );

  static Future<String> serviceRequestField({
    required String requestId,
    required Map<String, dynamic> fields,
  }) =>
      OfflineQueueService.instance.enqueue(
        _PendingOp.serviceRequestField(
            requestId: requestId, fields: fields),
      );

  static Future<String> partOrderStatus({
    required String requestId,
    required String status,
  }) =>
      OfflineQueueService.instance.enqueue(
        _PendingOp.partOrderStatus(
            requestId: requestId, status: status),
      );

  static Future<String> partOrderField({
    required String requestId,
    required Map<String, dynamic> fields,
  }) =>
      OfflineQueueService.instance.enqueue(
        _PendingOp.partOrderField(requestId: requestId, fields: fields),
      );

  static Future<String> requestMessage({
    required String requestId,
    required String senderId,
    required String message,
  }) =>
      OfflineQueueService.instance.enqueue(
        _PendingOp.requestMessage(
            requestId: requestId,
            senderId: senderId,
            message: message),
      );
}

/// Простой shim чтобы детектить network-исключения по сообщению.
/// Supabase возвращает разные типы — `SocketException` нативно есть только
/// на mobile, на web ошибки приходят как `ClientException`. Используем
/// строковое сравнение по подстроке.
class SocketException implements Exception {
  final String message;
  const SocketException(this.message);
  @override
  String toString() => 'SocketException: $message';
}
