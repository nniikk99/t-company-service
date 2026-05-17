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
  List<EquipmentPart> _parts = [];
  List<RecommendedPart> _selected = [];
  String _search = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _loadParts();
  }

  Future<void> _loadParts() async {
    try {
      final data = await SupabaseService.getEquipmentParts(widget.equipmentModel);
      setState(() {
        _parts = data.map((e) => EquipmentPart.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить каталог';
        _loading = false;
      });
    }
  }

  List<EquipmentPart> get _filtered {
    if (_search.isEmpty) return _parts;
    final q = _search.toLowerCase();
    return _parts.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.article.toLowerCase().contains(q) ||
      p.positionNumber.toString().contains(q),
    ).toList();
  }

  bool _isSelected(EquipmentPart part) =>
      _selected.any((s) => s.article == part.article);

  int _selectedQty(EquipmentPart part) =>
      _selected.firstWhere((s) => s.article == part.article,
          orElse: () => RecommendedPart(position: 0, article: '', name: '', qty: 0)).qty;

  Future<void> _onAdd(EquipmentPart part) async {
    final qty = await _showQtyDialog(part);
    if (qty == null || qty <= 0) return;
    setState(() {
      _selected.removeWhere((s) => s.article == part.article);
      _selected.add(RecommendedPart(
        position: part.positionNumber,
        article: part.article,
        name: part.name,
        qty: qty,
      ));
    });
  }

  void _onRemove(RecommendedPart part) {
    setState(() => _selected.removeWhere((s) => s.article == part.article));
  }

  Future<int?> _showQtyDialog(EquipmentPart part) async {
    int qty = _selectedQty(part).clamp(1, 99);
    if (qty == 0) qty = 1;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Позиция ${part.positionNumber}', style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(part.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Арт: ${part.article}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: qty > 1 ? () => setS(() => qty--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.blue,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: qty < 99 ? () => setS(() => qty++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, qty),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Column(
        children: [
          // Хэндл
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Заголовок
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Каталог запчастей',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${widget.equipmentManufacturer ?? ''} ${widget.equipmentModel}'.trim(),
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.check),
                  label: Text('Готово (${_selected.length})'),
                ),
              ],
            ),
          ),

          // Выбранные позиции
          if (_selected.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selected.map((p) => Chip(
                  label: Text('${p.position}. ${p.name} ×${p.qty}',
                      style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _onRemove(p),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.blue.shade200),
                )).toList(),
              ),
            ),
          ],

          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск по номеру, названию или артикулу...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // Список
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  _parts.isEmpty
                                      ? 'Каталог для этой модели пуст'
                                      : 'Ничего не найдено',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final part = _filtered[i];
                              final selected = _isSelected(part);
                              final qty = _selectedQty(part);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: selected ? Colors.blue : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${part.positionNumber}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: selected ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(part.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                subtitle: Text('Арт: ${part.article}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                trailing: selected
                                    ? GestureDetector(
                                        onTap: () => _onAdd(part),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text('×$qty',
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                        onPressed: () => _onAdd(part),
                                      ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
