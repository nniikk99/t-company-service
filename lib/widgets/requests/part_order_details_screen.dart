import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/service_request.dart';
import '../../models/user.dart' as AppUserModel;
import '../../services/supabase_service.dart';
import 'chat_screen.dart';

/// Экран детализации заказа запчастей.
/// Открывается из общего списка заявок при type=partsOrder.
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

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

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

  // ────────────────────────────────────────────────────────────────────────
  // Статусы и цвета
  // ────────────────────────────────────────────────────────────────────────

  Color _statusColor(RequestStatus s) {
    switch (s) {
      case RequestStatus.draft:
      case RequestStatus.pending:
        return const Color(0xFF3B82F6);
      case RequestStatus.approved:
      case RequestStatus.inProgress:
      case RequestStatus.waitingForAcceptance:
        return const Color(0xFFEA580C);
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

  String _statusLabel(RequestStatus s) {
    switch (s) {
      case RequestStatus.pending:
        return 'Новый';
      case RequestStatus.approved:
        return 'Принят';
      case RequestStatus.inProgress:
        return 'В сборке';
      case RequestStatus.waitingForAcceptance:
        return 'Готов к выдаче';
      case RequestStatus.completed:
        return 'Выполнен';
      case RequestStatus.cancelled:
        return 'Отменён';
      case RequestStatus.rejected:
        return 'Отклонён';
      default:
        return _request.statusDisplayName;
    }
  }

  Future<void> _updateStatus(String newDbStatus) async {
    setState(() => _isUpdating = true);
    try {
      await SupabaseService.updatePartOrderStatus(_request.id, newDbStatus);
      if (!mounted) return;
      // Перезагружаем актуальный статус — простое обновление локально
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

  // ────────────────────────────────────────────────────────────────────────

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
          if (_isSupplier) ...[
            const SizedBox(height: 16),
            _actionsBlock(),
          ],
        ],
      ),
    );
  }

  // ─── Блоки UI ──────────────────────────────────────────────────────────

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

  IconData _statusIcon(RequestStatus s) {
    switch (s) {
      case RequestStatus.pending:
        return Icons.hourglass_top_rounded;
      case RequestStatus.approved:
        return Icons.check_circle_outline_rounded;
      case RequestStatus.inProgress:
        return Icons.inventory_2_outlined;
      case RequestStatus.waitingForAcceptance:
        return Icons.storefront_outlined;
      case RequestStatus.completed:
        return Icons.done_all_rounded;
      case RequestStatus.cancelled:
      case RequestStatus.rejected:
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_rounded;
    }
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
                  color: _total > 0 ? const Color(0xFF1E293B) : const Color(0xFFEA580C),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Иконка/плейсхолдер фото
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.build_outlined,
              size: 22, color: Color(0xFFCBD5E1)),
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
    final isPickup = _deliveryType == 'pickup';
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
                  isPickup ? Icons.store_outlined : Icons.local_shipping_outlined,
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
                      isPickup ? 'Самовывоз' : 'Доставка',
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
          _contactRow(Icons.phone_outlined, 'Телефон', _contactPhone, isPhone: true),
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

  Widget _actionsBlock() {
    final s = _request.status;
    final List<Widget> buttons = [];

    if (s == RequestStatus.pending) {
      buttons.add(_primaryButton(
        'Принять в работу',
        Icons.check_circle_outline,
        () => _updateStatus('inProgress'),
      ));
    } else if (s == RequestStatus.inProgress) {
      buttons.add(_primaryButton(
        'Заказ выполнен',
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
        () => _updateStatus('cancelled'),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final b in buttons) ...[
          b,
          if (b != buttons.last) const SizedBox(height: 8),
        ]
      ],
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

  // ─── Чат ───────────────────────────────────────────────────────────────

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  const Text(
                    'Обсуждение заказа',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
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
  }
}
