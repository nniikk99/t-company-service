import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../requests/equipment_parts_sheet.dart';

/// Вкладка маркета: список моделей оборудования с заполненным каталогом
/// по схеме мануала. Тап по модели открывает EquipmentPartsSheet в режиме cart.
class CatalogsTab extends StatefulWidget {
  final User user;
  final VoidCallback? onCartUpdated;

  const CatalogsTab({super.key, required this.user, this.onCartUpdated});

  @override
  State<CatalogsTab> createState() => _CatalogsTabState();
}

class _CatalogsTabState extends State<CatalogsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _models = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final models = await SupabaseService.getModelsWithCatalog();
      setState(() {
        _models = models;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить каталоги: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _models;
    final q = _search.toLowerCase();
    return _models.where((m) {
      final name = (m['model'] ?? '').toString().toLowerCase();
      final mfg = (m['manufacturer'] ?? '').toString().toLowerCase();
      return name.contains(q) || mfg.contains(q);
    }).toList();
  }

  Future<void> _openCatalog(Map<String, dynamic> model) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EquipmentPartsSheet(
          equipmentModel: (model['model'] ?? '').toString(),
          equipmentManufacturer: (model['manufacturer'] ?? '').toString(),
          mode: PartsCatalogMode.cart,
          cartUserId: widget.user.id,
        ),
      ),
    );
    // По возврату — пускай корзина обновится
    widget.onCartUpdated?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    final list = _filtered;
    return Column(
      children: [
        // Поиск
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Поиск по модели или производителю...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _models.isEmpty
                            ? 'Каталоги ещё не добавлены'
                            : 'Ничего не найдено',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildModelCard(list[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildModelCard(Map<String, dynamic> model) {
    final modelName = (model['model'] ?? '').toString();
    final manufacturer = (model['manufacturer'] ?? '').toString();
    final coverUrl = model['cover_image_url'] as String?;
    final groupsCount = (model['groups_count'] as int?) ?? 0;
    final partsCount = (model['parts_count'] as int?) ?? 0;

    return InkWell(
      onTap: () => _openCatalog(model),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Обложка
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderCover(),
                      )
                    : _placeholderCover(),
              ),
            ),

            // Текст
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (manufacturer.isNotEmpty)
                      Text(manufacturer.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(modelName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(Icons.menu_book_outlined, '$groupsCount гр.'),
                        _chip(Icons.build_circle_outlined,
                            '$partsCount поз.'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      color: const Color(0xFFEFF6FF),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFF3B82F6), size: 36),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
