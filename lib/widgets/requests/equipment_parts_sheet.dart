import 'package:flutter/material.dart';
import '../../models/equipment_part.dart';
import '../../services/supabase_service.dart';

class EquipmentPartsSheet extends StatefulWidget {
  final String equipmentModel;
  final String? equipmentManufacturer;
  final List<RecommendedPart> initialSelected;

  const EquipmentPartsSheet({
    super.key,
    required this.equipmentModel,
    this.equipmentManufacturer,
    this.initialSelected = const [],
  });

  @override
  State<EquipmentPartsSheet> createState() => _EquipmentPartsSheetState();
}

class _EquipmentPartsSheetState extends State<EquipmentPartsSheet> {
  List<Map<String, dynamic>> _parts = [];
  List<RecommendedPart> _selected = [];
  String _search = '';
  String _selectedCategory = 'Все';
  bool _loading = true;

  final List<String> _categories = [
    'Все',
    'Расходные материалы',
    'Основные узлы',
    'Части корпуса',
    'Аксессуары',
    'Другое',
  ];

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _loadParts();
  }

  Future<void> _loadParts() async {
    try {
      final data = await SupabaseService.getSpareParts(
        modelFilter: widget.equipmentModel,
      );
      setState(() {
        _parts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _parts.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final article = (p['article'] ?? '').toString().toLowerCase();
      final q = _search.toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || article.contains(q);
      final matchesCat = _selectedCategory == 'Все' || p['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  bool _isSelected(Map<String, dynamic> part) =>
      _selected.any((s) => s.article == (part['article'] ?? ''));

  int _selectedQty(Map<String, dynamic> part) {
    try {
      return _selected.firstWhere((s) => s.article == (part['article'] ?? '')).qty;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _onTap(Map<String, dynamic> part) async {
    final article = part['article'] ?? '';
    final currentQty = _selectedQty(part).clamp(1, 99);
    final qty = await _showQtyDialog(part, currentQty == 0 ? 1 : currentQty);
    if (qty == null) return;
    if (qty <= 0) {
      setState(() => _selected.removeWhere((s) => s.article == article));
      return;
    }
    setState(() {
      _selected.removeWhere((s) => s.article == article);
      _selected.add(RecommendedPart(
        position: 0,
        article: article,
        name: part['name'] ?? '',
        qty: qty,
      ));
    });
  }

  Future<int?> _showQtyDialog(Map<String, dynamic> part, int initialQty) async {
    int qty = initialQty;
    final isAlreadySelected = _isSelected(part);

    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            part['name'] ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Арт: ${part['article'] ?? ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: qty > 1 ? () => setS(() => qty--) : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 28),
                    color: const Color(0xFF3B82F6),
                  ),
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF3B82F6)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$qty',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: qty < 99 ? () => setS(() => qty++) : null,
                    icon: const Icon(Icons.add_circle_outline, size: 28),
                    color: const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (isAlreadySelected)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 0),
                child: const Text('Убрать', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, qty),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Запчасти для ${widget.equipmentManufacturer != null ? '${widget.equipmentManufacturer} ' : ''}${widget.equipmentModel}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _selected),
            icon: const Icon(Icons.check, color: Color(0xFF3B82F6)),
            label: Text(
              'Готово${_selected.isNotEmpty ? ' (${_selected.length})' : ''}',
              style: const TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + categories
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск по артикулу или названию...',
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
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (v) { if (v) setState(() => _selectedCategory = cat); },
                        selectedColor: const Color(0xFF3B82F6).withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: _selectedCategory == cat ? const Color(0xFF3B82F6) : Colors.black87,
                          fontWeight: _selectedCategory == cat ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Selected chips summary
          if (_selected.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selected.map((p) => Chip(
                  label: Text('${p.name} ×${p.qty}',
                      style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() =>
                      _selected.removeWhere((s) => s.article == p.article)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
            ),

          // Grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _parts.isEmpty
                                  ? 'Запчасти для этой модели\nне найдены в каталоге'
                                  : 'Ничего не найдено',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final part = filtered[i];
                          final selected = _isSelected(part);
                          final qty = _selectedQty(part);
                          final images = part['images'] as List?;

                          return GestureDetector(
                            onTap: () => _onTap(part),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: selected
                                    ? Border.all(color: const Color(0xFF3B82F6), width: 2)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image
                                  Expanded(
                                    flex: 3,
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(14)),
                                          child: images != null && images.isNotEmpty
                                              ? Image.network(
                                                  images.first,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _partPlaceholder(),
                                                )
                                              : _partPlaceholder(),
                                        ),
                                        if (selected)
                                          Positioned(
                                            top: 8, right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '×$qty',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Info
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            part['name'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                          Text(
                                            'Арт: ${part['article'] ?? ''}',
                                            style: TextStyle(
                                                color: Colors.grey[600], fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              if (part['price'] != null)
                                                Text(
                                                  '${part['price']} ₽',
                                                  style: const TextStyle(
                                                    color: Color(0xFF2563EB),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                )
                                              else
                                                const SizedBox(),
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: selected
                                                      ? const Color(0xFF3B82F6)
                                                      : const Color(0xFFEFF6FF),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  selected
                                                      ? Icons.check
                                                      : Icons.add,
                                                  color: selected
                                                      ? Colors.white
                                                      : const Color(0xFF3B82F6),
                                                  size: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _partPlaceholder() => Container(
    width: double.infinity,
    color: const Color(0xFFEFF6FF),
    child: const Center(
      child: Icon(Icons.build_circle, size: 48, color: Color(0xFF3B82F6)),
    ),
  );
}
