import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';

/// Пошаговая шторка оформления заказа на запчасти.
/// Шаги: тип доставки → адрес → контакт → итог → подтверждение
class DeliveryCheckoutSheet extends StatefulWidget {
  final List<dynamic> cartItems;
  final Map<String, List<dynamic>> bySupplier;
  final User user;

  const DeliveryCheckoutSheet({
    super.key,
    required this.cartItems,
    required this.bySupplier,
    required this.user,
  });

  @override
  State<DeliveryCheckoutSheet> createState() => _DeliveryCheckoutSheetState();
}

class _DeliveryCheckoutSheetState extends State<DeliveryCheckoutSheet> {
  int _step = 0; // 0=тип, 1=адрес, 2=контакт, 3=итог

  // Выборы пользователя
  String _deliveryType = ''; // 'pickup' | 'address' | 'terminal'
  String _selectedWarehouseAddress = '';
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  // Данные поставщика и сохранённые предпочтения
  Map<String, dynamic>? _supplierData;
  Map<String, dynamic>? _savedPrefs;
  bool _loadingData = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Берём первого поставщика (в корзине могут быть разные, но доставка общая)
      final supplierId = widget.bySupplier.keys.first;
      final results = await Future.wait([
        SupabaseService.getSupplierById(supplierId),
        SupabaseService.getUserDeliveryPrefs(widget.user.id),
      ]);
      final supplier = results[0] as Map<String, dynamic>?;
      final prefs = results[1] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _supplierData = supplier;
          _savedPrefs = prefs;
          _loadingData = false;
        });

        // Предзаполняем поля из прошлого заказа
        if (prefs != null) {
          _addressController.text = prefs['delivery_address'] ?? '';
          _nameController.text = prefs['contact_name'] ?? '';
          _phoneController.text = prefs['contact_phone'] ?? '';
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  List<Map<String, dynamic>> get _warehouses {
    final raw = _supplierData?['warehouse_addresses'];
    if (raw == null) return [];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  bool get _hasSavedPrefs =>
      _savedPrefs != null &&
      (_savedPrefs!['contact_name'] ?? '').toString().isNotEmpty;

  double get _total => widget.cartItems.fold(
        0,
        (s, i) =>
            s +
            ((i['spare_parts']?['price'] as num?)?.toDouble() ?? 0) *
                (i['quantity'] as int),
      );

  bool get _allByRequest => _total == 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ручка
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Прогресс-бар шагов
          _buildStepIndicator(),
          // Контент текущего шага
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: _loadingData
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _buildStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Доставка', 'Адрес', 'Контакт', 'Итог'];
    // Если самовывоз — шаг "адрес" пропускается по логике, но индикатор остаётся
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        decoration: BoxDecoration(
                          color: done || active
                              ? const Color(0xFF3B82F6)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: active
                              ? const Color(0xFF3B82F6)
                              : done
                                  ? Colors.black54
                                  : Colors.grey[400],
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildDeliveryTypeStep();
      case 1:
        return _buildAddressStep();
      case 2:
        return _buildContactStep();
      case 3:
        return _buildSummaryStep();
      default:
        return const SizedBox();
    }
  }

  // ─── Шаг 0: тип доставки ─────────────────────────────────────────────────

  Widget _buildDeliveryTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Как получить заказ?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Выберите удобный способ',
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 24),

        // Самовывоз
        _DeliveryOptionCard(
          icon: Icons.store_outlined,
          title: 'Самовывоз',
          subtitle: _warehouses.isEmpty
              ? 'Уточните адрес склада у поставщика'
              : '${_warehouses.length} ${_warehouseWord(_warehouses.length)}',
          selected: _deliveryType == 'pickup',
          onTap: () => setState(() => _deliveryType = 'pickup'),
        ),
        const SizedBox(height: 12),

        // Доставка до адреса
        _DeliveryOptionCard(
          icon: Icons.home_outlined,
          title: 'Доставка до адреса',
          subtitle: 'Курьер привезёт по вашему адресу',
          selected: _deliveryType == 'address',
          onTap: () => setState(() => _deliveryType = 'address'),
        ),
        const SizedBox(height: 12),

        // Доставка до терминала
        _DeliveryOptionCard(
          icon: Icons.local_shipping_outlined,
          title: 'До терминала ТК',
          subtitle: 'Транспортная компания — СДЭК, Деловые линии и др.',
          selected: _deliveryType == 'terminal',
          onTap: () => setState(() => _deliveryType = 'terminal'),
        ),

        // Адреса складов при выборе самовывоза
        if (_deliveryType == 'pickup' && _warehouses.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Выберите склад:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._warehouses.map((w) => _WarehouseCard(
                warehouse: w,
                selected: _selectedWarehouseAddress ==
                    (w['address'] as String? ?? ''),
                onTap: () => setState(() =>
                    _selectedWarehouseAddress = w['address'] as String? ?? ''),
              )),
        ],

        if (_deliveryType == 'pickup' && _warehouses.isEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFF97316), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Поставщик не указал адреса складов. Контакт для уточнения: '
                    '${_supplierData?['contact_phone'] ?? _supplierData?['support_phone'] ?? '—'}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFF97316)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),
        _NextButton(
          label: 'Продолжить',
          enabled: _deliveryType.isNotEmpty &&
              (_deliveryType != 'pickup' ||
                  _warehouses.isEmpty ||
                  _selectedWarehouseAddress.isNotEmpty),
          onTap: () {
            if (_deliveryType == 'pickup') {
              // При самовывозе сразу к контакту
              setState(() => _step = 2);
            } else {
              setState(() => _step = 1);
            }
          },
        ),
      ],
    );
  }

  String _warehouseWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'склад';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'склада';
    }
    return 'складов';
  }

  // ─── Шаг 1: адрес доставки ───────────────────────────────────────────────

  Widget _buildAddressStep() {
    final isTerminal = _deliveryType == 'terminal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTerminal ? 'Адрес терминала ТК' : 'Адрес доставки',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          isTerminal
              ? 'Укажите название ТК и адрес терминала'
              : 'Укажите точный адрес куда доставить',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),

        // Подсказка из прошлого заказа
        if (_hasSavedPrefs &&
            (_savedPrefs!['delivery_type'] == _deliveryType) &&
            (_savedPrefs!['delivery_address'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          _SavedPrefsBanner(
            text: _savedPrefs!['delivery_address'],
            onUse: () => _addressController.text =
                _savedPrefs!['delivery_address'] ?? '',
          ),
        ],

        const SizedBox(height: 20),
        TextField(
          controller: _addressController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: isTerminal
                ? 'Например: СДЭК, г. Москва, ул. Ленина 5'
                : 'Город, улица, дом, квартира/офис',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            _BackButton(onTap: () => setState(() => _step = 0)),
            const SizedBox(width: 12),
            Expanded(
              child: _NextButton(
                label: 'Продолжить',
                enabled: _addressController.text.trim().length > 5,
                onTap: () => setState(() => _step = 2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Шаг 2: контакт ──────────────────────────────────────────────────────

  Widget _buildContactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Контакт для связи',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Поставщик свяжется с вами по этим данным',
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),

        // Предложить данные из прошлого заказа
        if (_hasSavedPrefs) ...[
          const SizedBox(height: 16),
          _SavedContactBanner(
            name: _savedPrefs!['contact_name'] ?? '',
            phone: _savedPrefs!['contact_phone'] ?? '',
            onUse: () {
              setState(() {
                _nameController.text = _savedPrefs!['contact_name'] ?? '';
                _phoneController.text = _savedPrefs!['contact_phone'] ?? '';
              });
            },
          ),
        ],

        const SizedBox(height: 20),
        _InputField(
          controller: _nameController,
          label: 'Ваше имя',
          hint: 'Иван Петров',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _InputField(
          controller: _phoneController,
          label: 'Телефон',
          hint: '+7 999 123-45-67',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _InputField(
          controller: _notesController,
          label: 'Комментарий (необязательно)',
          hint: 'Уточнения по заказу...',
          icon: Icons.comment_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            _BackButton(
                onTap: () => setState(
                    () => _step = _deliveryType == 'pickup' ? 0 : 1)),
            const SizedBox(width: 12),
            Expanded(
              child: _NextButton(
                label: 'К итогу',
                enabled: _nameController.text.trim().isNotEmpty &&
                    _phoneController.text.trim().length >= 7,
                onTap: () => setState(() => _step = 3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Шаг 3: итог и подтверждение ─────────────────────────────────────────

  Widget _buildSummaryStep() {
    final deliveryLabel = {
          'pickup': 'Самовывоз',
          'address': 'Доставка до адреса',
          'terminal': 'Доставка до терминала ТК',
        }[_deliveryType] ??
        _deliveryType;

    final address = _deliveryType == 'pickup'
        ? _selectedWarehouseAddress.isEmpty
            ? 'Уточнить у поставщика'
            : _selectedWarehouseAddress
        : _addressController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ваш заказ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // Список позиций
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              ...widget.cartItems.map((item) {
                final part = item['spare_parts'] as Map<String, dynamic>? ?? {};
                final equipPart =
                    item['equipment_parts'] as Map<String, dynamic>? ?? {};
                final name = (part['name'] as String?) ??
                    (equipPart['name'] as String?) ??
                    '—';
                final article = (part['article'] as String?) ??
                    (equipPart['article'] as String?) ??
                    '—';
                final qty = item['quantity'] as int;
                final price =
                    (part['price'] as num?)?.toDouble() ?? 0.0;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Text('Арт: $article',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('× $qty',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          price > 0
                              ? Text('${(price * qty).toStringAsFixed(0)} ₽',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3B82F6)))
                              : const Text('По запросу',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFF97316),
                                      fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Итого:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    _allByRequest
                        ? const Text('По запросу',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF97316),
                                fontSize: 16))
                        : Text('${_total.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                                fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Детали доставки
        _SummaryRow(icon: Icons.local_shipping_outlined, label: deliveryLabel),
        if (address.isNotEmpty)
          _SummaryRow(icon: Icons.location_on_outlined, label: address),
        _SummaryRow(
            icon: Icons.person_outline,
            label: _nameController.text.trim()),
        _SummaryRow(
            icon: Icons.phone_outlined,
            label: _phoneController.text.trim()),
        if (_notesController.text.trim().isNotEmpty)
          _SummaryRow(
              icon: Icons.comment_outlined,
              label: _notesController.text.trim()),

        const SizedBox(height: 28),
        Row(
          children: [
            _BackButton(onTap: () => setState(() => _step = 2)),
            const SizedBox(width: 12),
            Expanded(
              child: _submitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Оформить заказ',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Отправка заказа ─────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final address = _deliveryType == 'pickup'
          ? _selectedWarehouseAddress
          : _addressController.text.trim();

      for (final entry in widget.bySupplier.entries) {
        final supplierId = entry.key;
        final items = entry.value;
        final total = items.fold<double>(
          0,
          (s, i) =>
              s +
              ((i['spare_parts']?['price'] as num?)?.toDouble() ?? 0) *
                  (i['quantity'] as int),
        );

        final orderItems = items.map((item) {
          final part = item['spare_parts'] as Map<String, dynamic>? ?? {};
          final equipPart =
              item['equipment_parts'] as Map<String, dynamic>? ?? {};
          return {
            'part_id': item['part_id'],
            'equipment_part_id': item['equipment_part_id'],
            'quantity': item['quantity'],
            'price_at_order': (part['price'] as num?)?.toDouble() ?? 0,
            'article': part['article'] ?? equipPart['article'] ?? '',
            'name': part['name'] ?? equipPart['name'] ?? '',
          };
        }).toList();

        await SupabaseService.createPartOrderWithDelivery(
          clientId: widget.user.id,
          supplierId: supplierId,
          totalAmount: total,
          items: orderItems,
          deliveryType: _deliveryType,
          deliveryAddress: address,
          contactName: _nameController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          notes: _notesController.text.trim(),
        );
      }

      // Сохраняем предпочтения пользователя
      await SupabaseService.saveUserDeliveryPrefs(
        userId: widget.user.id,
        deliveryType: _deliveryType,
        deliveryAddress: _deliveryType == 'pickup' ? '' : _addressController.text.trim(),
        contactName: _nameController.text.trim(),
        contactPhone: _phoneController.text.trim(),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
        setState(() => _submitting = false);
      }
    }
  }
}

// ─── Вспомогательные виджеты ─────────────────────────────────────────────────

class _DeliveryOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF3B82F6).withOpacity(0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: selected
                      ? const Color(0xFF3B82F6)
                      : Colors.grey[500],
                  size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected ? const Color(0xFF3B82F6) : Colors.black87)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 22),
          ],
        ),
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  final Map<String, dynamic> warehouse;
  final bool selected;
  final VoidCallback onTap;

  const _WarehouseCard(
      {required this.warehouse, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.warehouse_outlined,
                color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(warehouse['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(warehouse['address'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if ((warehouse['hours'] ?? '').toString().isNotEmpty)
                    Text(warehouse['hours'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 20),
          ],
        ),
      ),
    );
  }
}

class _SavedPrefsBanner extends StatelessWidget {
  final String text;
  final VoidCallback onUse;
  const _SavedPrefsBanner({required this.text, required this.onUse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFF86EFAC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Color(0xFF16A34A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Прошлый раз: $text',
              style: const TextStyle(fontSize: 13, color: Color(0xFF15803D)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onUse,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              foregroundColor: const Color(0xFF16A34A),
            ),
            child: const Text('Использовать',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SavedContactBanner extends StatelessWidget {
  final String name;
  final String phone;
  final VoidCallback onUse;
  const _SavedContactBanner(
      {required this.name, required this.phone, required this.onUse});

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty && phone.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFF86EFAC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Color(0xFF16A34A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Прошлый раз: $name${phone.isNotEmpty ? ', $phone' : ''}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF15803D)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onUse,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              foregroundColor: const Color(0xFF16A34A),
            ),
            child: const Text('Использовать',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _NextButton(
      {required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          disabledBackgroundColor: Colors.grey[200],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: const Icon(Icons.arrow_back, size: 20),
    );
  }
}
