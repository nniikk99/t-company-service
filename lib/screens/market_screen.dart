import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../widgets/market/catalogs_tab.dart';
import '../widgets/market/delivery_checkout_sheet.dart';
import '../widgets/requests/part_order_details_screen.dart';

class MarketScreen extends StatefulWidget {
  final User user;
  const MarketScreen({super.key, required this.user});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15))),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: const Color(0xFF3B82F6),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.menu_book_outlined, size: 20), text: 'Каталоги'),
                  Tab(icon: Icon(Icons.shopping_cart_outlined, size: 20), text: 'Корзина'),
                  Tab(icon: Icon(Icons.favorite_border, size: 20), text: 'Избранное'),
                  Tab(icon: Icon(Icons.search, size: 20), text: 'Поиск'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  CatalogsTab(
                    user: widget.user,
                    onCartUpdated: () => setState(() {}),
                  ),
                  _CartTab(
                    user: widget.user,
                    onGoToCatalog: () => _tabController.animateTo(0),
                  ),
                  _FavoritesTab(user: widget.user),
                  _SearchTab(user: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════
// TAB 1 — КОРЗИНА
// ═══════════════════════════════════

class _CartTab extends StatefulWidget {
  final User user;
  final VoidCallback? onGoToCatalog;
  const _CartTab({required this.user, this.onGoToCatalog});

  @override
  State<_CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<_CartTab> {
  bool _isLoading = true;
  List<dynamic> _cartItems = [];

  /// Имена поставщиков по suppliers.id (для группировки корзины)
  final Map<String, String> _supplierNames = {};

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    try {
      final items = await SupabaseService.getCartItems(widget.user.id);
      _cartItems = items;
      await _loadSupplierNames();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки корзины: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Подгружает названия компаний поставщиков из таблицы suppliers.
  Future<void> _loadSupplierNames() async {
    final ids = <String>{};
    for (final item in _cartItems) {
      final id = item['supplier_id_hint'] as String?;
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return;
    for (final id in ids) {
      if (_supplierNames.containsKey(id)) continue;
      try {
        final row = await SupabaseService.getSupplierById(id);
        _supplierNames[id] = (row?['company_name'] as String?)?.trim().isNotEmpty == true
            ? row!['company_name'] as String
            : 'Поставщик';
      } catch (_) {
        _supplierNames[id] = 'Поставщик';
      }
    }
  }

  /// Группировка позиций корзины по supplier_id_hint.
  Map<String, List<dynamic>> get _groupedCart {
    final map = <String, List<dynamic>>{};
    for (final item in _cartItems) {
      final key = (item['supplier_id_hint'] as String?) ?? 'unknown';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Future<void> _updateQuantity(String cartItemId, int newQty) async {
    if (newQty <= 0) {
      await _removeItem(cartItemId);
      return;
    }
    try {
      await SupabaseService.updateCartItemQuantity(cartItemId, newQty);
      await _loadCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeItem(String cartItemId) async {
    try {
      await SupabaseService.removeFromCart(cartItemId);
      await _loadCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkout() async {
    if (_cartItems.isEmpty) return;

    // Группируем товары по поставщикам.
    // Приоритет: spare_parts.supplier_id → equipment_models.default_supplier_id
    final Map<String, List<dynamic>> bySupplier = {};
    final Map<String, String> modelToSupplier = {}; // кэш модель → supplier_id

    for (final item in _cartItems) {
      final spPart = item['spare_parts'] as Map<String, dynamic>? ?? {};
      String? supplierId = spPart['supplier_id'] as String?;

      if (supplierId == null || supplierId.isEmpty) {
        // Ищем через equipment_parts → equipment_model → default_supplier_id
        final equipPart = item['equipment_parts'] as Map<String, dynamic>?;
        final modelName = equipPart?['equipment_model'] as String? ?? '';
        if (modelName.isNotEmpty) {
          supplierId = modelToSupplier[modelName] ??
              await SupabaseService.getSupplierIdByModel(modelName);
          if (supplierId != null) modelToSupplier[modelName] = supplierId;
        }
      }

      // Проверяем, что supplier_id реально существует (suppliers.id или user_profiles.id).
      // Если нет — пытаемся резолвить как user_profiles.id и обратно. Висячие → 'unknown'.
      if (supplierId != null && supplierId.isNotEmpty) {
        final resolved = await SupabaseService.resolveSupplierToUserId(supplierId);
        if (resolved == null) supplierId = null;
      }

      bySupplier.putIfAbsent(supplierId ?? 'unknown', () => []).add(item);
    }

    // Если все товары ушли в 'unknown' — понятная ошибка
    final knownSuppliers = bySupplier.keys.where((k) => k != 'unknown').toList();
    if (knownSuppliers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось определить поставщика для товаров в корзине. '
              'Обратитесь в поддержку.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    bySupplier.remove('unknown');

    // Открываем пошаговую шторку доставки
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => DeliveryCheckoutSheet(
          cartItems: _cartItems,
          bySupplier: bySupplier,
          user: widget.user,
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // Заказ уже создан внутри DeliveryCheckoutSheet
      // Очищаем корзину
      await SupabaseService.clearCart(widget.user.id);
      await _loadCart();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка оформления: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// Модалка успешного оформления с кнопками
  /// «Открыть заказ» (push на PartOrderDetailsScreen) и «Закрыть».
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 44),
            ),
            const SizedBox(height: 18),
            const Text('Заказ оформлен!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Поставщик получил ваш заказ и скоро его подтвердит. Отслеживайте статус в разделе «Заявки».',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await _openLatestOrder();
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Открыть заказ',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2937),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: const Text('Продолжить покупки',
                      style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Открыть только что созданный заказ в детальном экране.
  Future<void> _openLatestOrder() async {
    final order = await SupabaseService.getLatestPartOrderAsServiceRequest(
      widget.user.id,
    );
    if (!mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть заказ. Зайдите в раздел «Заявки».'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // Конвертируем User → AppUserModel-совместимого пользователя.
    // PartOrderDetailsScreen ожидает AppUserModel.User, а у нас тот же тип
    // (импортируется как User здесь). Подходит.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartOrderDetailsScreen(
          request: order,
          currentUser: widget.user,
          onStatusChanged: () {},
        ),
      ),
    );
  }

  void _showPartDetail(
    BuildContext context, {
    required String name,
    required String article,
    required String imageUrl,
    required String equipModel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            // Фото — единый контейнер во всю ширину
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.build_outlined,
                              size: 72, color: Color(0xFF3B82F6)),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.build_outlined,
                          size: 72, color: Color(0xFF3B82F6)),
                    ),
            ),
            const SizedBox(height: 20),
            // Название
            Text(name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            // Артикул
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Арт: $article',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            ),
            if (equipModel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Модель: $equipModel',
                  style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  double get _total => _cartItems.fold(
    0,
    (sum, item) => sum + (item['spare_parts']?['price'] as num? ?? 0) * (item['quantity'] as int),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_cartItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(48),
                ),
                child: const Icon(Icons.shopping_cart_outlined,
                    size: 44, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(height: 20),
              Text('Корзина пуста',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text(
                'Найдите запчасти в каталоге — выберите\nмодель техники и нужные позиции',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (widget.onGoToCatalog != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onGoToCatalog,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Перейти в каталог',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Сборка списка с заголовками-поставщиками
    final grouped = _groupedCart;
    final List<Widget> listChildren = [];
    grouped.forEach((supplierId, items) {
      final supplierName = _supplierNames[supplierId] ?? 'Поставщик';
      // Подсчёт суммы группы
      final groupTotal = items.fold<double>(0, (s, i) {
        final p = i['spare_parts'] as Map<String, dynamic>? ?? {};
        return s + ((p['price'] as num?)?.toDouble() ?? 0) * (i['quantity'] as int);
      });

      // Заголовок группы
      listChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplierName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${items.length} ${_partsWord(items.length)}'
                      '${groupTotal > 0 ? ' · ${groupTotal.toStringAsFixed(0)} ₽' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Карточки товаров группы
      for (final item in items) {
        listChildren.add(_buildCartItemCard(item));
      }
      listChildren.add(const SizedBox(height: 8));
    });

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: listChildren,
          ),
        ),
        // Итого + Оформить (вынесено в отдельный метод чтобы build был чище)
        _buildCheckoutBar(),
      ],
    );
  }

  String _partsWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'позиция';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'позиции';
    }
    return 'позиций';
  }

  Widget _buildCartItemCard(dynamic item) {
              final part = item['spare_parts'] as Map<String, dynamic>? ?? {};
              final qty = item['quantity'] as int;
              final price = (part['price'] as num?)?.toDouble() ?? 0.0;

              // Берём фото: сначала из spare_parts.images, иначе из equipment_parts.image_url
              final spareImages = part['images'] as List?;
              final equipPart = item['equipment_parts'] as Map<String, dynamic>?;
              final imageUrl = (spareImages != null && spareImages.isNotEmpty)
                  ? spareImages.first as String
                  : (equipPart?['image_url'] as String? ?? '');
              final partName = part['name'] as String? ??
                  equipPart?['name'] as String? ?? '';
              final article = part['article'] as String? ??
                  equipPart?['article'] as String? ?? '';
              final equipModel = equipPart?['equipment_model'] as String? ?? '';

              return GestureDetector(
                onTap: () => _showPartDetail(
                  context,
                  name: partName,
                  article: article,
                  imageUrl: imageUrl,
                  equipModel: equipModel,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Фото запчасти
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: const Color(0xFFEFF6FF),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.build_circle,
                                        color: Color(0xFF3B82F6),
                                        size: 28),
                                  )
                                : const Icon(Icons.build_circle,
                                    color: Color(0xFF3B82F6), size: 28),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(partName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('Арт: $article',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              if (equipModel.isNotEmpty)
                                Text(equipModel,
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF3B82F6))),
                              const SizedBox(height: 4),
                              price > 0
                                  ? Text('${(price * qty).toStringAsFixed(0)} ₽',
                                      style: const TextStyle(
                                          color: Color(0xFF3B82F6),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15))
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('По запросу',
                                          style: TextStyle(
                                              color: Color(0xFFF97316),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12)),
                                    ),
                            ],
                          ),
                        ),
                        // Qty controls
                        Row(
                          children: [
                            _QtyButton(
                              icon: Icons.remove,
                              onTap: () => _updateQuantity(item['id'], qty - 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$qty',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            _QtyButton(
                              icon: Icons.add,
                              onTap: () => _updateQuantity(item['id'], qty + 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Итого (${_cartItems.length} ${_partsWord(_cartItems.length)}):',
                    style: TextStyle(color: Colors.grey[600])),
                _total > 0
                    ? Text('${_total.toStringAsFixed(0)} ₽',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87))
                    : const Text('По запросу',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF97316))),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Оформить заказ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}

// Шторка подтверждения заказа
class _CheckoutSheet extends StatelessWidget {
  final List<dynamic> cartItems;
  final Map<String, List<dynamic>> bySupplier;
  const _CheckoutSheet({required this.cartItems, required this.bySupplier});

  @override
  Widget build(BuildContext context) {
    final total = cartItems.fold<double>(
      0,
      (s, i) => s + (i['spare_parts']['price'] as num) * (i['quantity'] as int),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            const Text('Подтверждение заказа',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...cartItems.map((item) {
              final part = item['spare_parts'] as Map<String, dynamic>;
              final qty = item['quantity'] as int;
              final price = (part['price'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${part['name']} × $qty',
                          style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                    ),
                    price > 0
                        ? Text('${(price * qty).toStringAsFixed(0)} ₽',
                            style: const TextStyle(fontWeight: FontWeight.bold))
                        : const Text('По запросу',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF97316),
                                fontSize: 13)),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Итого:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                total > 0
                    ? Text('${total.toStringAsFixed(0)} ₽',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF3B82F6)))
                    : const Text('По запросу',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFF97316))),
              ],
            ),
            const SizedBox(height: 8),
            Text('Заказов: ${bySupplier.length} (от разных поставщиков)',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Подтвердить', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════
// TAB 2 — ИЗБРАННОЕ
// ═══════════════════════════════════

class _FavoritesTab extends StatefulWidget {
  final User user;
  const _FavoritesTab({required this.user});

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  bool _isLoading = true;
  List<dynamic> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favs = await SupabaseService.getFavorites(widget.user.id);
      setState(() => _favorites = favs);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromFavorites(String favId) async {
    try {
      await SupabaseService.removeFromFavorites(favId);
      await _loadFavorites();
    } catch (_) {}
  }

  Future<void> _addToCart(String partId) async {
    try {
      await SupabaseService.addToCart(widget.user.id, partId, 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Добавлено в корзину!'),
            backgroundColor: Color(0xFF3B82F6),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Нет избранных товаров',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Нажмите ♡ на карточке товара',
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final fav = _favorites[index];
        final part = fav['spare_parts'] as Map<String, dynamic>? ?? {};
        final price = (part['price'] as num?)?.toDouble() ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.build_circle, color: Color(0xFF3B82F6)),
            ),
            title: Text(part['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${price.toStringAsFixed(0)} ₽',
                style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart_outlined, color: Color(0xFF3B82F6)),
                  onPressed: () => _addToCart(fav['part_id']),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _removeFromFavorites(fav['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════
// TAB 3 — ПОИСК ТОВАРА
// ═══════════════════════════════════

class _SearchTab extends StatefulWidget {
  final User user;
  const _SearchTab({required this.user});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _results = [];
  String _selectedCategory = 'Все';
  bool _searched = false;

  final List<String> _categories = ['Все', 'Расходные материалы', 'Основные узлы', 'Части корпуса', 'Аксессуары', 'Другое'];

  Future<void> _search() async {
    setState(() { _isLoading = true; _searched = true; });
    try {
      final parts = await SupabaseService.getSpareParts(
        category: _selectedCategory == 'Все' ? null : _selectedCategory,
        modelFilter: null,
      );
      final query = _searchController.text.toLowerCase();
      setState(() {
        _results = query.isEmpty
            ? parts
            : parts.where((p) =>
                p['name'].toString().toLowerCase().contains(query) ||
                p['article'].toString().toLowerCase().contains(query)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка поиска: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToCart(String partId) async {
    try {
      await SupabaseService.addToCart(widget.user.id, partId, 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Добавлено в корзину!'),
            backgroundColor: Color(0xFF3B82F6),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addToFavorites(String partId) async {
    try {
      await SupabaseService.addToFavorites(widget.user.id, partId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Добавлено в избранное!'),
            backgroundColor: Colors.pink,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Поисковая строка + фильтры
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Артикул, название запчасти...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Найти'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 10),
                    child: ChoiceChip(
                      label: Text(cat, style: TextStyle(
                        fontSize: 12,
                        color: _selectedCategory == cat ? const Color(0xFF3B82F6) : Colors.black87,
                        fontWeight: _selectedCategory == cat ? FontWeight.bold : FontWeight.normal,
                      )),
                      selected: _selectedCategory == cat,
                      selectedColor: const Color(0xFF3B82F6).withOpacity(0.15),
                      onSelected: (s) { if (s) setState(() => _selectedCategory = cat); },
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),

        // Результаты
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_searched
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Введите запрос для поиска запчастей',
                              style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    )
                  : _results.isEmpty
                      ? Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey[500])))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final part = _results[index];
                            final price = (part['price'] as num?)?.toDouble() ?? 0.0;
                            final images = part['images'] as List?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8, offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 64, height: 64,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: images != null && images.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                images.first,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.build_circle, color: Color(0xFF3B82F6), size: 32),
                                              ),
                                            )
                                          : const Icon(Icons.build_circle, color: Color(0xFF3B82F6), size: 32),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(part['name'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 2),
                                          Text('Арт: ${part['article'] ?? ''}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                          if (part['description'] != null && part['description'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(part['description'],
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ),
                                          const SizedBox(height: 6),
                                          Text('${price.toStringAsFixed(0)} ₽',
                                              style: const TextStyle(
                                                  color: Color(0xFF3B82F6),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.favorite_border, color: Colors.pink, size: 22),
                                          onPressed: () => _addToFavorites(part['id']),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () => _addToCart(part['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            minimumSize: Size.zero,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          child: const Text('В корзину', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
