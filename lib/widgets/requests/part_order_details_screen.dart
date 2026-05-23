import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:url_launcher/url_launcher.dart';
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
            if (!mounted) return;

            // 1. Обновляем статус если изменился
            final newStatus = newRow['status'] as String?;
            if (newStatus != null) {
              final mapped = RequestStatus.values.firstWhere(
                (e) => e.toString() == 'RequestStatus.$newStatus',
                orElse: () => _request.status,
              );
              if (mapped != _request.status) {
                setState(() {
                  _request = _request.copyWith(status: mapped);
                });
              }
            }

            // 2. Синхронизируем поля счёта/оплаты/отгрузки в _details
            //    (чтобы блок «Оплата» и «Отгрузка» обновились у клиента сразу)
            setState(() {
              _details['invoice_pdf_url'] = newRow['invoice_pdf_url'];
              _details['invoice_file_name'] = newRow['invoice_file_name'];
              _details['invoice_uploaded_at'] = newRow['invoice_uploaded_at'];
              _details['payment_due_days'] = newRow['payment_due_days'];
              _details['payment_received_at'] = newRow['payment_received_at'];
              _details['tracking_url'] = newRow['tracking_url'];
              _details['tracking_carrier'] = newRow['tracking_carrier'];
              _details['shipped_at'] = newRow['shipped_at'];
              _details['pickup_ready_at'] = newRow['pickup_ready_at'];
            });
          },
        )
        .subscribe();
    _subscription = ch;
  }

  // ── Геттеры ─────────────────────────────────────────────────────────────

  /// Локальная мутабельная копия деталей заказа.
  /// Инициализируется лениво из widget.request.partsOrderDetails и переписывается
  /// при загрузке счёта / смене оплаты / приходе realtime-апдейта.
  Map<String, dynamic>? _detailsCache;
  Map<String, dynamic> get _details {
    _detailsCache ??=
        Map<String, dynamic>.from(_request.partsOrderDetails ?? const {});
    return _detailsCache!;
  }

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
          const SizedBox(height: 12),
          _shipmentBlock(),
          if (_notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _notesBlock(),
          ],
          const SizedBox(height: 12),
          _paymentBlock(),
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

  // ── Отгрузка ──────────────────────────────────────────────────────────

  String? get _trackingUrl {
    final v = _details['tracking_url'];
    return v is String && v.isNotEmpty ? v : null;
  }

  String? get _trackingCarrier {
    final v = _details['tracking_carrier'];
    return v is String && v.isNotEmpty ? v : null;
  }

  DateTime? get _shippedAt {
    final raw = _details['shipped_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  DateTime? get _pickupReadyAt {
    final raw = _details['pickup_ready_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  bool get _isShipped => _trackingUrl != null || _shippedAt != null;
  bool get _isPickupReady => _pickupReadyAt != null;

  Widget _shipmentBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPickup
                    ? Icons.inventory_2_outlined
                    : Icons.local_shipping_outlined,
                size: 18,
                color: const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                _isPickup ? 'Готовность к выдаче' : 'Отслеживание',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              _shipmentStatusBadge(),
            ],
          ),
          const SizedBox(height: 12),
          if (_isPickup) _pickupView() else _deliveryTrackingView(),
        ],
      ),
    );
  }

  Widget _shipmentStatusBadge() {
    if (_isPickup) {
      if (_isPickupReady) {
        return _pillBadge('Готов', const Color(0xFF16A34A));
      }
      return _pillBadge('Готовится', const Color(0xFF94A3B8));
    } else {
      if (_isShipped) {
        return _pillBadge('Отправлен', const Color(0xFF16A34A));
      }
      return _pillBadge('Не отправлен', const Color(0xFF94A3B8));
    }
  }

  Widget _pillBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ─── Самовывоз ──────────────────────────────────────────────────────────

  Widget _pickupView() {
    if (_isPickupReady) {
      final readyAt = _pickupReadyAt!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFEF1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Можно забирать',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Реализация проведена ${DateFormat('dd.MM.yyyy в HH:mm').format(readyAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Адрес склада крупно
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _deliveryAddress.isNotEmpty
                        ? _deliveryAddress
                        : 'Адрес уточните у поставщика',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
          if (_isSupplier) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : _undoPickupReady,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Снять отметку готовности',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Не готов
    if (_isSupplier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Когда в 1С проведёте реализацию — нажмите «Готов к выдаче». Клиент увидит, что заказ можно забирать на складе.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _markPickupReady,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Готов к выдаче',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }
    // Клиент видит ожидание
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.hourglass_top_rounded,
              size: 18, color: Color(0xFF94A3B8)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Поставщик готовит ваш заказ. Когда товар можно будет забрать со склада — вы увидите подтверждение здесь.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markPickupReady() async {
    final ok = await _confirmDialog(
        'Отметить заказ готовым к выдаче? Клиент увидит, что можно забирать товар на складе.');
    if (ok != true) return;
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.markOrderPickupReady(_request.id, true);
      // Также переводим статус в waitingForAcceptance чтобы синхронизировать
      if (_request.status != RequestStatus.waitingForAcceptance) {
        await SupabaseService.updatePartOrderStatus(
            _request.id, 'waitingForAcceptance');
      }
      _details['pickup_ready_at'] = DateTime.now().toIso8601String();
      if (mounted) {
        setState(() {
          _request = _request.copyWith(
            status: RequestStatus.waitingForAcceptance,
          );
        });
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _undoPickupReady() async {
    final ok = await _confirmDialog(
        'Снять отметку готовности? Клиент снова увидит, что заказ готовится.');
    if (ok != true) return;
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.markOrderPickupReady(_request.id, false);
      // Возвращаем статус в inProgress
      await SupabaseService.updatePartOrderStatus(_request.id, 'inProgress');
      _details['pickup_ready_at'] = null;
      if (mounted) {
        setState(() {
          _request = _request.copyWith(status: RequestStatus.inProgress);
        });
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ─── Доставка: трекинг ──────────────────────────────────────────────────

  Widget _deliveryTrackingView() {
    if (_isShipped) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_trackingUrl != null)
            InkWell(
              onTap: _openTracking,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _trackingCarrier ?? 'Отслеживание',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _trackingUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded,
                        size: 18, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
          if (_shippedAt != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              Icons.event_available_rounded,
              'Отправлен',
              DateFormat('dd.MM.yyyy в HH:mm').format(_shippedAt!),
              color: const Color(0xFF16A34A),
            ),
          ],
          if (_isSupplier) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUpdating ? null : _editTracking,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Изменить',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      foregroundColor: const Color(0xFF3B82F6),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUpdating ? null : _clearTracking,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Удалить',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Не отправлен
    if (_isSupplier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Когда передадите заказ в ТК — укажите трек-номер или ссылку для отслеживания. Клиент сможет следить за доставкой.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _editTracking,
              icon: const Icon(Icons.add_link),
              label: const Text('Добавить трек-номер',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }
    // Клиент — ожидание отправки
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.hourglass_top_rounded,
              size: 18, color: Color(0xFF94A3B8)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Поставщик готовит отправку. Когда заказ будет передан транспортной компании — здесь появится ссылка для отслеживания.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTracking() async {
    final url = _trackingUrl;
    if (url == null) return;
    // Дополняем http:// если нет схемы
    final fixedUrl = url.startsWith(RegExp(r'https?://')) ? url : 'https://$url';
    final uri = Uri.tryParse(fixedUrl);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть ссылку'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editTracking() async {
    final result = await _showTrackingDialog(
      initialCarrier: _trackingCarrier ?? '',
      initialUrl: _trackingUrl ?? '',
    );
    if (result == null) return;
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.setOrderTracking(
        orderId: _request.id,
        trackingUrl: result.url,
        carrier: result.carrier.isNotEmpty ? result.carrier : null,
      );
      // Также переводим статус в waitingForAcceptance если ещё не там
      if (_request.status != RequestStatus.waitingForAcceptance) {
        await SupabaseService.updatePartOrderStatus(
            _request.id, 'waitingForAcceptance');
      }
      _details['tracking_url'] = result.url;
      _details['tracking_carrier'] =
          result.carrier.isNotEmpty ? result.carrier : null;
      _details['shipped_at'] = DateTime.now().toIso8601String();
      if (mounted) {
        setState(() {
          _request = _request.copyWith(
              status: RequestStatus.waitingForAcceptance);
        });
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _clearTracking() async {
    final ok = await _confirmDialog(
        'Удалить трек-номер? Клиент перестанет видеть ссылку отслеживания.');
    if (ok != true) return;
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.clearOrderTracking(_request.id);
      // Возвращаем статус
      if (_request.status == RequestStatus.waitingForAcceptance) {
        await SupabaseService.updatePartOrderStatus(_request.id, 'inProgress');
      }
      _details['tracking_url'] = null;
      _details['tracking_carrier'] = null;
      _details['shipped_at'] = null;
      if (mounted) {
        setState(() {
          if (_request.status == RequestStatus.waitingForAcceptance) {
            _request = _request.copyWith(status: RequestStatus.inProgress);
          }
        });
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<_TrackingInput?> _showTrackingDialog({
    required String initialCarrier,
    required String initialUrl,
  }) async {
    final carrierCtrl = TextEditingController(text: initialCarrier);
    final urlCtrl = TextEditingController(text: initialUrl);
    return showDialog<_TrackingInput>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Трек-номер отслеживания'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Транспортная компания',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: carrierCtrl,
                decoration: InputDecoration(
                  hintText: 'СДЭК, Деловые линии, Почта России...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Ссылка для отслеживания',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: urlCtrl,
                maxLines: 2,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Можно указать полную ссылку с сайта ТК или сам трек-номер',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Укажите ссылку или трек-номер'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(
                ctx,
                _TrackingInput(
                  carrier: carrierCtrl.text.trim(),
                  url: url,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // ── Оплата ────────────────────────────────────────────────────────────

  String? get _invoiceUrl => _details['invoice_pdf_url'] as String?;
  String? get _invoiceFileName => _details['invoice_file_name'] as String?;
  DateTime? get _invoiceUploadedAt {
    final raw = _details['invoice_uploaded_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  int? get _paymentDueDays => (_details['payment_due_days'] as num?)?.toInt();

  DateTime? get _paymentReceivedAt {
    final raw = _details['payment_received_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  DateTime? get _paymentDueDate {
    final uploaded = _invoiceUploadedAt;
    final days = _paymentDueDays;
    if (uploaded == null || days == null) return null;
    return uploaded.add(Duration(days: days));
  }

  /// Статус оплаты для отображения и логики
  _PaymentState get _paymentState {
    if (_invoiceUrl == null || _invoiceUrl!.isEmpty) {
      return _PaymentState.notInvoiced;
    }
    if (_paymentReceivedAt != null) {
      return _PaymentState.paid;
    }
    final due = _paymentDueDate;
    if (due != null && DateTime.now().isAfter(due)) {
      return _PaymentState.overdue;
    }
    return _PaymentState.awaitingPayment;
  }

  Widget _paymentBlock() {
    final state = _paymentState;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              const Text(
                'Оплата',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              _paymentStatusBadge(state),
            ],
          ),
          const SizedBox(height: 12),
          if (state == _PaymentState.notInvoiced)
            _paymentEmptyView()
          else
            _paymentInvoiceView(state),
        ],
      ),
    );
  }

  Widget _paymentStatusBadge(_PaymentState s) {
    final (label, color) = switch (s) {
      _PaymentState.notInvoiced =>
        ('Счёт не выставлен', const Color(0xFF94A3B8)),
      _PaymentState.awaitingPayment =>
        ('Ожидает оплаты', const Color(0xFFEA580C)),
      _PaymentState.overdue => ('Просрочен', const Color(0xFFEF4444)),
      _PaymentState.paid => ('Оплачен', const Color(0xFF16A34A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _paymentEmptyView() {
    if (_isSupplier) {
      // Поставщик может выставить счёт
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  style: BorderStyle.solid,
                  width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    size: 28, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Сформируйте счёт в 1С и загрузите PDF — клиент сможет его открыть и оплатить.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _uploadInvoice,
              icon: const Icon(Icons.upload_file),
              label: const Text('Выставить счёт',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }
    // Клиент: ждёт счёт
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.hourglass_top_rounded,
              size: 18, color: Color(0xFF94A3B8)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Поставщик подготовит счёт. Появится здесь — вы получите уведомление.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentInvoiceView(_PaymentState state) {
    final uploaded = _invoiceUploadedAt;
    final due = _paymentDueDate;
    final paid = _paymentReceivedAt;
    final fileName = _invoiceFileName ?? 'Счёт.pdf';

    final daysLeft = due != null
        ? due.difference(DateTime.now()).inDays
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Карточка PDF
        InkWell(
          onTap: _openInvoice,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (uploaded != null)
                        Text(
                          'Выставлен ${DateFormat('dd.MM.yyyy').format(uploaded)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new_rounded,
                    size: 18, color: Color(0xFF2563EB)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Срок оплаты / дата оплаты
        if (state == _PaymentState.paid && paid != null)
          _infoRow(
            Icons.check_circle_rounded,
            'Оплачен',
            DateFormat('dd.MM.yyyy в HH:mm').format(paid),
            color: const Color(0xFF16A34A),
          )
        else if (due != null) ...[
          _infoRow(
            Icons.calendar_today_rounded,
            'Срок оплаты',
            '${DateFormat('dd.MM.yyyy').format(due)} '
                '(${_paymentDueDays ?? 0} ${_daysWord(_paymentDueDays ?? 0)})',
          ),
          const SizedBox(height: 4),
          _infoRow(
            state == _PaymentState.overdue
                ? Icons.error_outline_rounded
                : Icons.access_time_rounded,
            'Осталось',
            state == _PaymentState.overdue
                ? 'Просрочен на ${-(daysLeft ?? 0)} '
                    '${_daysWord(-(daysLeft ?? 0))}'
                : daysLeft != null && daysLeft >= 0
                    ? '$daysLeft ${_daysWord(daysLeft)}'
                    : '—',
            color: state == _PaymentState.overdue
                ? const Color(0xFFEF4444)
                : null,
          ),
        ] else
          _infoRow(
            Icons.info_outline_rounded,
            'Срок оплаты',
            'не задан',
            color: const Color(0xFF94A3B8),
          ),

        // Действия поставщика по оплате
        if (_isSupplier) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUpdating ? null : _selectPaymentDueDays,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    _paymentDueDays == null
                        ? 'Указать отсрочку'
                        : 'Изменить срок',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: state == _PaymentState.paid
                    ? OutlinedButton.icon(
                        onPressed:
                            _isUpdating ? null : () => _setPaymentPaid(false),
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Отменить оплату',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed:
                            _isUpdating ? null : () => _setPaymentPaid(true),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Оплачен',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: _isUpdating ? null : _confirmRemoveInvoice,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Заменить / удалить файл',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _daysWord(int n) {
    final v = n.abs();
    if (v % 10 == 1 && v % 100 != 11) return 'день';
    if (v % 10 >= 2 && v % 10 <= 4 && (v % 100 < 10 || v % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }

  Future<void> _openInvoice() async {
    final url = _invoiceUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть PDF'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadInvoice() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Не удалось прочитать файл'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }

      setState(() => _isUpdating = true);
      final publicUrl = await SupabaseService.uploadOrderInvoice(
        orderId: _request.id,
        bytes: bytes,
        fileName: f.name,
      );

      // Обновляем локально, чтобы UI отрисовал без перезагрузки
      _details['invoice_pdf_url'] = publicUrl;
      _details['invoice_file_name'] = f.name;
      _details['invoice_uploaded_at'] = DateTime.now().toIso8601String();

      // Если отсрочка ещё не задана — спрашиваем сразу
      if (_paymentDueDays == null) {
        await _selectPaymentDueDays();
      }

      if (mounted) {
        setState(() {});
        widget.onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Счёт загружен'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка загрузки: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _confirmRemoveInvoice() async {
    final ok = await _confirmDialog(
        'Удалить выставленный счёт? Его нужно будет загрузить заново.');
    if (ok != true) return;
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.removeOrderInvoice(_request.id);
      _details['invoice_pdf_url'] = null;
      _details['invoice_file_name'] = null;
      _details['invoice_uploaded_at'] = null;
      if (mounted) {
        setState(() {});
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _selectPaymentDueDays() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Отсрочка платежа',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Сколько дней с момента выставления счёта даётся на оплату',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ),
              for (final d in const [3, 5, 7, 10, 14, 30, 60])
                ListTile(
                  title: Text('$d ${_daysWord(d)}'),
                  trailing: _paymentDueDays == d
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF3B82F6))
                      : null,
                  onTap: () => Navigator.pop(ctx, d),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, -1),
                child: const Text('Без срока',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    final days = picked == -1 ? null : picked;
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.setOrderPaymentDueDays(_request.id, days);
      _details['payment_due_days'] = days;
      if (mounted) {
        setState(() {});
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _setPaymentPaid(bool paid) async {
    if (!paid) {
      final ok = await _confirmDialog(
          'Снять отметку об оплате? Заказ снова станет «ожидает оплаты».');
      if (ok != true) return;
    }
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.markOrderPaymentReceived(_request.id, paid);
      _details['payment_received_at'] =
          paid ? DateTime.now().toIso8601String() : null;
      if (mounted) {
        setState(() {});
        widget.onStatusChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paid
                ? 'Отмечено: оплата получена'
                : 'Отметка об оплате снята'),
            backgroundColor: paid
                ? const Color(0xFF16A34A)
                : const Color(0xFF94A3B8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ── Действия ──────────────────────────────────────────────────────────

  Widget _actionsBlock() {
    final s = _request.status;
    final List<Widget> buttons = [];

    // Действия поставщика.
    // Переход inProgress → waitingForAcceptance делается через блок «Отгрузка»
    // (там одновременно вводится трек-номер для delivery или ставится отметка
    // готовности для pickup), поэтому в общем actions-блоке он не дублируется.
    if (_isSupplier) {
      if (s == RequestStatus.pending) {
        buttons.add(_primaryButton(
          'Принять в работу',
          Icons.check_circle_outline,
          () => _updateStatus('inProgress'),
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

/// Введённые поставщиком данные для трека: ТК и ссылка/номер.
class _TrackingInput {
  final String carrier;
  final String url;
  const _TrackingInput({required this.carrier, required this.url});
}

/// Состояние оплаты заказа — вычисляется из полей invoice_* и payment_*.
enum _PaymentState {
  /// Поставщик ещё не выставил счёт.
  notInvoiced,

  /// Счёт выставлен, оплата не получена, срок не вышел (или не задан).
  awaitingPayment,

  /// Счёт выставлен, срок оплаты прошёл, оплата не получена.
  overdue,

  /// Оплата подтверждена поставщиком.
  paid,
}

