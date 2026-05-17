import 'package:flutter/material.dart';
import '../../models/equipment_part.dart';
import '../../services/supabase_service.dart';

/// Полноэкранный каталог запчастей по группам мануала.
/// Сверху — PDF-схема группы, снизу — список позиций с кнопкой "+".
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
  List<Map<String, dynamic>> _groups = [];
  Map<String, List<Map<String, dynamic>>> _partsByGroup = {};
  List<RecommendedPart> _selected = [];
  int _currentGroupIndex = 0;
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await SupabaseService.getPartGroups(widget.equipmentModel);
      setState(() {
        _groups = groups;
        _loading = false;
      });
      if (groups.isNotEmpty) {
        _loadPartsForCurrent();
      }
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить каталог: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadPartsForCurrent() async {
    if (_currentGroupIndex >= _groups.length) return;
    final group = _groups[_currentGroupIndex];
    final groupId = group['id'] as String;
    if (_partsByGroup.containsKey(groupId)) return;
    try {
      final parts = await SupabaseService.getPartsByGroup(groupId);
      if (mounted) {
        setState(() => _partsByGroup[groupId] = parts);
      }
    } catch (_) {}
  }

  Map<String, dynamic>? get _currentGroup =>
      _groups.isNotEmpty && _currentGroupIndex < _groups.length
          ? _groups[_currentGroupIndex]
          : null;

  List<Map<String, dynamic>> get _currentParts {
    final g = _currentGroup;
    if (g == null) return [];
    final all = _partsByGroup[g['id'] as String] ?? [];
    if (_search.isEmpty) return all;
    final q = _search.toLowerCase();
    return all.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final article = (p['article'] ?? '').toString().toLowerCase();
      return name.contains(q) || article.contains(q);
    }).toList();
  }

  int _selectedQty(String article) {
    try {
      return _selected.firstWhere((s) => s.article == article).qty;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _onAdd(Map<String, dynamic> part) async {
    final article = (part['article'] ?? '').toString();
    final currentQty = _selectedQty(article);
    final qty = await _showQtyDialog(part, currentQty == 0 ? 1 : currentQty);
    if (qty == null) return;
    setState(() {
      _selected.removeWhere((s) => s.article == article);
      if (qty > 0) {
        _selected.add(RecommendedPart(
          position: (part['position_number'] as int?) ?? 0,
          article: article,
          name: (part['name'] ?? '').toString(),
          qty: qty,
        ));
      }
    });
  }

  Future<int?> _showQtyDialog(Map<String, dynamic> part, int initialQty) async {
    int qty = initialQty;
    final isAlreadySelected = _selectedQty((part['article'] ?? '').toString()) > 0;

    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Поз. ${part['position_number']}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF3B82F6)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(part['name'] ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Арт: ${part['article'] ?? ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
                    child: Text('$qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
              ),
              child: Text(isAlreadySelected ? 'Изменить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _goToGroup(int index) {
    if (index < 0 || index >= _groups.length) return;
    setState(() {
      _currentGroupIndex = index;
      _search = '';
    });
    _loadPartsForCurrent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollPaginationToCurrent());
  }

  @override
  void dispose() {
    _paginationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              '${widget.equipmentManufacturer ?? ''} ${widget.equipmentModel}'.trim().toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Каталог запчастей',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.pop(context, _selected),
              ),
              if (_selected.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${_selected.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _groups.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text('Каталог для этой модели пуст',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              'Искали по: "${widget.equipmentModel}"',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Производитель: "${widget.equipmentManufacturer ?? "—"}"',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildContent(),
      bottomNavigationBar: _groups.isEmpty ? null : _buildPagination(),
    );
  }

  Widget _buildContent() {
    final group = _currentGroup!;
    final figureNum = group['figure_number'] as int;
    final groupName = group['group_name'] as String;
    final parts = _currentParts;

    final diagramUrl = group['diagram_image_url'] as String?;

    return Column(
      children: [
        // Схема сверху (статичная картинка, ~35% высоты)
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.32,
          child: (diagramUrl == null || diagramUrl.isEmpty)
              ? _placeholderDiagram(figureNum, groupName)
              : Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.network(
                      diagramUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, __, ___) => _placeholderDiagram(figureNum, groupName),
                    ),
                  ),
                ),
        ),

        // Заголовок группы
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('ГР. $figureNum',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  groupName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Шапка таблицы
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: const [
              SizedBox(
                width: 30,
                child: Text('№',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('АРТИКУЛ / НАИМЕНОВАНИЕ',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold)),
              ),
              Text('КОЛ-ВО',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold)),
              SizedBox(width: 50),
            ],
          ),
        ),

        // Список позиций
        Expanded(
          child: parts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Загрузка позиций...',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              : ListView.separated(
                  itemCount: parts.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, i) => _buildPartRow(parts[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildPartRow(Map<String, dynamic> part) {
    final article = (part['article'] ?? '').toString();
    final selectedQty = _selectedQty(article);
    final isSelected = selectedQty > 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Номер позиции
          SizedBox(
            width: 30,
            child: Text(
              '${part['position_number']}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Артикул + название
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  (part['name'] ?? '').toString(),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Количество (из мануала)
          SizedBox(
            width: 50,
            child: Text(
              '× ${part['qty'] ?? 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),

          // Кнопка "+"
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onAdd(part),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1F2937),
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? Center(
                      child: Text(
                        '×$selectedQty',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  : const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderDiagram(int figureNum, String name) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEFF6FF),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_outlined, size: 48, color: Color(0xFF3B82F6)),
            const SizedBox(height: 8),
            Text('Fig. $figureNum', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(name, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            const Text('PDF мануал не задан', style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  final ScrollController _paginationController = ScrollController();

  Widget _buildPagination() {
    if (_groups.length <= 1) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            _navBtn(Icons.chevron_left, _currentGroupIndex > 0,
                () => _goToGroup(_currentGroupIndex - 1)),
            Expanded(
              child: ListView.builder(
                controller: _paginationController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _groups.length,
                itemBuilder: (_, i) => _pageBtn(i),
              ),
            ),
            _navBtn(Icons.chevron_right, _currentGroupIndex < _groups.length - 1,
                () => _goToGroup(_currentGroupIndex + 1)),
          ],
        ),
      ),
    );
  }

  void _scrollPaginationToCurrent() {
    if (!_paginationController.hasClients) return;
    const btnWidth = 46.0; // 40 ширина + 2*3 padding
    final target = (_currentGroupIndex * btnWidth) - 100;
    _paginationController.animateTo(
      target.clamp(0.0, _paginationController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: enabled ? Colors.black87 : Colors.grey[400], size: 20),
        ),
      ),
    );
  }

  Widget _pageBtn(int index) {
    final isCurrent = index == _currentGroupIndex;
    final fig = _groups[index]['figure_number'] as int;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _goToGroup(index),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isCurrent ? const Color(0xFF1F2937) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? const Color(0xFF1F2937) : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              '$fig',
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.black87,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController(text: _search);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Поиск в текущей группе'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Артикул или название...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Сбросить'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Искать'),
          ),
        ],
      ),
    );
    if (res != null) setState(() => _search = res);
  }
}

