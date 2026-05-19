import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../widgets/market/catalogs_tab.dart';
import '../widgets/market/delivery_checkout_sheet.dart';
import 'client_spare_parts_screen.dart';

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
                  _CartTab(user: widget.user),
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
  const _CartTab({required this.user});

  @override
  State<_CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<_CartTab> {
  bool _isLoading = true;
  List<dynamic> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _isLoading = true);
    try {
      final items = await SupabaseService.getCartItems(widget.user.id);
      setState(() => _cartItems = items);
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

    // Группируем товары по поставщикам
    // Берём supplier_id из spare_parts или из equipment_models через equipment_part
    final Map<String, List<dynamic>> bySupplier = {};
    for (final item in _cartItems) {
      final spPart = item['spare_parts'] as Map<String, dynamic>? ?? {};
      final supplierId = (spPart['supplier_id'] as String?) ?? 'unknown';
      bySupplier.putIfAbsent(supplierId, () => []).add(item);
    }

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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Заказ оформлен!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Ваш заказ передан поставщику. Вы можете отследить его статус в разделе "Заявки".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Отлично!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
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
        padding: const EdgeInsets.all(24),
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
            // Фото
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: const Color(0xFFEFF6FF),
                    child: const Center(
                      child: Icon(Icons.build_outlined,
                          size: 64, color: Color(0xFF3B82F6)),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.build_outlined,
                      size: 64, color: Color(0xFF3B82F6)),
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
            const SizedBox(height: 24),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Корзина пуста',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Найдите запчасти во вкладке «Поиск»',
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
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
            },
          ),
        ),
        // Итого + Оформить
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Итого (${_cartItems.length} товаров):',
                        style: TextStyle(color: Colors.grey[600])),
                    _total > 0
                        ? Text('${_total.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87))
                        : const Text('По запросу',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Оформить заказ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
