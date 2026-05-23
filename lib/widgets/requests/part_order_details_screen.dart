import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../models/service_request.dart';
import '../../models/user.dart' as AppUserModel;
import '../../services/supabase_service.dart';
import 'chat_screen.dart';

/// Экран детализации заказа запчастей.
/// Открывается из общего списка заявок при type=partsOrder.
///
/// Особенности:
/// - подгружает реальные фото товаров из equipment_parts / spare_parts;
/// - кнопки действий зависят от роли пользователя и текущего статуса
///   (клиент может отменить свой pending-заказ, поставщик ведёт через этапы);
/// - подписан на realtime-изменения part_orders — статус обновляется мгновенно;
/// - чат-обсуждение открывается во всю шторку.
class PartOrderDetailsScreen extends StatefulWidget {
  final ServiceRequest request;
  final AppUserModel.User currentUser;
  final VoidCallback? onStatusChanged;

  const PartOrderDetailsScreen({
    super.key,
    required this.request,
    required this.currentUser,
    this.onStatusChanged,
  });

  @override
  State<PartOrderDetailsScreen> createState() => _PartOrderDetailsScreenState();
}

class _PartOrderDetailsScreenState extends State<PartOrderDetailsScreen> {
  late ServiceRequest _request;
  bool _isUpdating = false;

  // Кеш фото товаров: ключ — equipment_part_id или part_id
  final Map<String, String> _imageCache = {};
  bool _imagesLoading = true;

  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _loadItemImages();
    _setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  // ── Загрузка фото товаров ───────────────────────────────────────────────

  Future<void> _loadItemImages() async {
    final equipIds = <String>{};
    final partIds = <String>{};
    for (final item in _items) {
      final eId = item['equipment_part_id'] as String?;
      final pId = item['part_id'] as String?;
      if (eId != null && eId.isNotEmpty) equipIds.add(eId);
      if (pId != null && pId.isNotEmpty) partIds.add(pId);
    }

    try {
      if (equipIds.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('equipment_parts')
            .select('id, image_url')
            .inFilter('id', equipIds.toList());
        for (final r in (rows as List)) {
          final m = r as Map<String, dynamic>;
          final url = (m['image_url'] as String?) ?? '';
          if (url.isNotEmpty) _imageCache[m['id'] as String] = url;
        }
      }
      if (partIds.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('spare_parts')
            .select('id, images')
            .inFilter('id', partIds.toList());
        for (final r in (rows as List)) {
          final m = r as Map<String, dynamic>;
          final imgs = m['images'];
          if (imgs is List && imgs.isNotEmpty) {
            _imageCache[m['id'] as String] = imgs.first.toString();
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Не удалось загрузить фото товаров: $e');
    }
    if (mounted) setState(() => _imagesLoading = false);
  }

  String? _imageFor(Map<String, dynamic> item) {
    final eId = item['equipment_part_id'] as String?;
    final pId = item['part_id'] as String?;
    if (eId != null && _imageCache[eId] != null) return _imageCache[eId];
    if (pId != null && _imageCache[pId] != null) return _imageCache[pId];
    return null;
  }

  // ── Realtime подписка на статус ──────────────────────────────────────────

  void _setupRealtime() {
    final ch = Supabase.instance.client
        .channel('part_order_${_request.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'part_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _request.id,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            final newStatus = newRow['status'] as String?;
            if (newStatus == null) return;
            final mapped = RequestStatus.values.firstWhere(
              (e) => e.toString() == 'RequestStatus.$newStatus',
              orElse: () => _request.status,
            );
            if (mounted && mapped != _request.status) {
              setState(() {
                _request = _request.copyWith(status: mapped);
              });
            }
          },
        )
        .subscribe();
    _subscription = ch;
  }

  // ── Геттеры ─────────────────────────────────────────────────────────────

  Map<String, dynamic> get _details =>
      _request.partsOrderDetails ?? const <String, dynamic>{};

  List<Map<String, dynamic>> get _items {
    final raw = _details['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  double get _total => (_details['total_amount'] as num?)?.toDouble() ?? 0;
  String get _deliveryType => (_details['delivery_type'] ?? '').toString();
  String get _deliveryAddress => (_details['delivery_address'] ?? '').toString();
  String get _contactName => (_details['contact_name'] ?? '').toString();
  String get _contactPhone => (_details['contact_phone'] ?? '').toString();
  String get _notes => (_details['notes'] ?? '').toString();

  bool get _isSupplier =>
      widget.currentUser.role == AppUserModel.UserRole.supplier ||
      widget.currentUser.role == AppUserModel.UserRole.administrator;

  bool get _isClient =>
      widget.currentUser.id == _request.userId ||
      widget.currentUser.id == _request.clientId;

  bool get _isPickup => _deliveryType == 'pickup';

  // ── Статусы ────────────────────────────────────────────────────────────

  Color _statusColor(RequestStatus s) {
    switch (s) {
      case RequestStatus.draft:
      case RequestStatus.pending:
        return const Color(0xFF3B82F6);
      case RequestStatus.approved:
      case RequestStatus.inProgress:
        return const Color(0xFFEA580C);
      case RequestStatus.waitingForAcceptance:
        return const Color(0xFF8B5CF6);
      case RequestStatus.waitingForInvoice:
      case RequestStatus.waitingForPayment:
        return const Color(0xFF8B5CF6);
      case RequestStatus.completed:
        return const Color(0xFF16A34A);
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  /// Подпись статуса. Учитываем тип доставки для waitingForAcceptance.
  String _statusLabel(RequestStatus s) {
    switch (s) {
      case RequestStatus.pending:
        return 'Новый';
      case RequestStatus.approved:
        return 'Принят';
      case RequestStatus.inProgress:
        return 'В сборке';
      case RequestStatus.waitingForAcceptance:
        return _isPickup ? 'Готов к выдаче' : 'Отправлен';
      case RequestStatus.completed:
        return _isPickup ? 'Выдан' : 'Доставлен';
      case RequestStatus.cancelled:
        return 'Отменён';
      case RequestStatus.rejected:
        return 'Отклонён';
      default:
        return _request.statusDisplayName;
    }
  }

  IconData _statusIcon(RequestStatus s) {
    switch (s) {
      case RequestStatus.pending:
        return Icons.hourglass_top_rounded;
      case RequestStatus.approved:
      case RequestStatus.inProgress:
        return Icons.inventory_2_outlined;
      case RequestStatus.waitingForAcceptance:
        return _isPickup
            ? Icons.storefront_rounded
            : Icons.local_shipping_rounded;
      case RequestStatus.completed:
        return Icons.done_all_rounded;
      case RequestStatus.cancelled:
      case RequestStatus.rejected:
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Future<void> _updateStatus(String newDbStatus, {String? confirmText}) async {
    if (confirmText != null) {
      final ok = await _confirmDialog(confirmText);
      if (ok != true) return;
    }
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.updatePartOrderStatus(_request.id, newDbStatus);
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(
          status: RequestStatus.values.firstWhere(
            (e) => e.toString() == 'RequestStatus.$newDbStatus',
            orElse: () => _request.status,
          ),
        );
      });
      widget.onStatusChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Статус обновлён: ${_statusLabel(_request.status)}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<bool?> _confirmDialog(String text) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Подтвердите действие'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            child: const Text('Да'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Заказ запчастей',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              _request.displayId,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: Color(0xFF64748B)),
            tooltip: 'Обсуждение',
            onPressed: _openChat,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _statusBlock(),
          const SizedBox(height: 12),
          _summaryBlock(),
          const SizedBox(height: 12),
          _itemsBlock(),
          const SizedBox(height: 12),
          _deliveryBlock(),
          if (_notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _notesBlock(),
          ],
          const SizedBox(height: 16),
          _actionsBlock(),
        ],
      ),
    );
  }

  // ── Блоки UI ───────────────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _statusBlock() {
    final color = _statusColor(_request.status);
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon(_request.status), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(_request.status),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Создан ${DateFormat('dd.MM.yyyy в HH:mm').format(_request.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBlock() {
    final qtyTotal = _items.fold<int>(
      0,
      (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0),
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Итого',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _total > 0
                    ? '${_total.toStringAsFixed(0)} ₽'
                    : 'По запросу',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _total > 0
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEA580C),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_items.length} поз. · $qtyTotal шт.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemsBlock() {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Состав заказа',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _items.length; i++) ...[
            _itemRow(_items[i]),
            if (i < _items.length - 1)
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final article = (item['article'] ?? '').toString();
    final name = (item['name'] ?? '').toString();
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['price_at_order'] as num?)?.toDouble() ?? 0;
    final sum = price * qty;
    final imageUrl = _imageFor(item);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Фото или плейсхолдер
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 56,
            height: 56,
            color: const Color(0xFFF1F5F9),
            child: _imagesLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.build_outlined,
                            size: 22,
                            color: Color(0xFFCBD5E1)),
                      )
                    : const Icon(Icons.build_outlined,
                        size: 22, color: Color(0xFFCBD5E1)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.isNotEmpty ? article : '—',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '× $qty',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sum > 0 ? '${sum.toStringAsFixed(0)} ₽' : 'По запросу',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sum > 0
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFEA580C),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _deliveryBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isPickup
                      ? Icons.store_outlined
                      : Icons.local_shipping_outlined,
                  color: const Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPickup ? 'Самовывоз' : 'Доставка',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _deliveryAddress.isNotEmpty ? _deliveryAddress : '—',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          _contactRow(Icons.person_outline_rounded, 'Получатель', _contactName),
          const SizedBox(height: 8),
          _contactRow(Icons.phone_outlined, 'Телефон', _contactPhone,
              isPhone: true),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value,
      {bool isPhone = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPhone
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _notesBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Комментарий клиента',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _notes,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  // ── Действия ──────────────────────────────────────────────────────────

  Widget _actionsBlock() {
    final s = _request.status;
    final List<Widget> buttons = [];

    // Действия поставщика
    if (_isSupplier) {
      if (s == RequestStatus.pending) {
        buttons.add(_primaryButton(
          'Принять в работу',
          Icons.check_circle_outline,
          () => _updateStatus('inProgress'),
        ));
      } else if (s == RequestStatus.inProgress) {
        // В сборке → готов / отправлен (зависит от типа)
        buttons.add(_primaryButton(
          _isPickup ? 'Готов к выдаче' : 'Отправить',
          _isPickup
              ? Icons.storefront_rounded
              : Icons.local_shipping_rounded,
          () => _updateStatus('waitingForAcceptance'),
        ));
      } else if (s == RequestStatus.waitingForAcceptance) {
        // Готов / отправлен → выполнен
        buttons.add(_primaryButton(
          _isPickup ? 'Отметить как выданный' : 'Отметить как доставленный',
          Icons.done_all_rounded,
          () => _updateStatus('completed'),
        ));
      }

      if (s != RequestStatus.completed &&
          s != RequestStatus.cancelled &&
          s != RequestStatus.rejected) {
        buttons.add(_secondaryButton(
          'Отменить заказ',
          Icons.cancel_outlined,
          () => _updateStatus('cancelled',
              confirmText: 'Отменить этот заказ? Действие нельзя отменить.'),
        ));
      }
    }

    // Действия клиента — можно отменить только пока pending
    if (_isClient && !_isSupplier) {
      if (s == RequestStatus.pending) {
        buttons.add(_secondaryButton(
          'Отменить заказ',
          Icons.cancel_outlined,
          () => _updateStatus('cancelled',
              confirmText:
                  'Вы уверены, что хотите отменить заказ? Восстановить его будет нельзя.'),
        ));
      }
      // Подтверждение получения для клиента, когда поставщик отметил готовность
      if (s == RequestStatus.waitingForAcceptance) {
        buttons.add(_primaryButton(
          _isPickup ? 'Я забрал заказ' : 'Я получил заказ',
          Icons.done_all_rounded,
          () => _updateStatus('completed'),
        ));
      }
    }

    if (buttons.isEmpty) {
      // Если действий нет — показываем подсказку статуса
      return _statusHintBlock();
    }

    return Column(
      children: [
        for (final b in buttons) ...[
          b,
          if (b != buttons.last) const SizedBox(height: 8),
        ]
      ],
    );
  }

  Widget _statusHintBlock() {
    String hint;
    switch (_request.status) {
      case RequestStatus.completed:
        hint = 'Заказ закрыт. Спасибо!';
        break;
      case RequestStatus.cancelled:
        hint = 'Заказ был отменён.';
        break;
      case RequestStatus.rejected:
        hint = 'Заказ был отклонён поставщиком.';
        break;
      case RequestStatus.waitingForAcceptance:
        hint = _isPickup
            ? 'Заказ ожидает вас на складе поставщика.'
            : 'Заказ отправлен и едет к вам.';
        break;
      case RequestStatus.inProgress:
        hint = 'Поставщик собирает ваш заказ.';
        break;
      case RequestStatus.pending:
        hint = 'Заказ передан поставщику, ожидайте подтверждения.';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Color(0xFF2563EB), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isUpdating ? null : onTap,
        icon: Icon(icon),
        label: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1F2937),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _secondaryButton(String text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isUpdating ? null : onTap,
        icon: Icon(icon, color: const Color(0xFFEF4444)),
        label: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFFEF4444))),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ── Чат ───────────────────────────────────────────────────────────────

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // useSafeArea + isScrollControlled — корректная работа с клавиатурой:
      // sheet поднимается над клавиатурой целиком.
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        // Высота шторки: всё доступное пространство, поднимается над клавиатурой
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ручка
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Шапка
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.forum_outlined,
                          size: 20, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      const Text(
                        'Обсуждение заказа',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close,
                            color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Expanded(
                  child: ChatWidget(
                    requestId: _request.id,
                    requestTitle: 'Заказ ${_request.displayId}',
                    currentUser: widget.currentUser,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
