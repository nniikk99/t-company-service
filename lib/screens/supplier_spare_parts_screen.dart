import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';

class SupplierSparePartsScreen extends StatefulWidget {
  final User supplier;
  const SupplierSparePartsScreen({super.key, required this.supplier});

  @override
  State<SupplierSparePartsScreen> createState() => _SupplierSparePartsScreenState();
}

class _SupplierSparePartsScreenState extends State<SupplierSparePartsScreen> {
  bool _isLoading = true;
  List<dynamic> _spareParts = [];
  List<String> _availableModels = []; // Реальные модели из парка поставщика
  String _searchQuery = '';
  String _selectedCategory = 'Все';

  final List<String> _categories = [
    'Все',
    'Расходные материалы',
    'Основные узлы',
    'Части корпуса',
    'Аксессуары',
    'Другое'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Загружаем запчасти и модели оборудования поставщика параллельно
      final results = await Future.wait([
        SupabaseService.getSupplierSpareParts(widget.supplier.id),
        SupabaseService().getSupplierEquipmentModels(widget.supplier.id),
      ]);

      final parts = results[0] as List;
      final models = results[1] as List;

      setState(() {
        _spareParts = parts;
        // Формируем строки "Производитель Модель"
        _availableModels = models
            .map((m) => '${m.manufacturer ?? ''} ${m.model ?? ''}'.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePart(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запчасть?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteSparePart(id);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showAddEditPartDialog({Map<String, dynamic>? part}) {
    final isEditing = part != null;
    final articleController = TextEditingController(text: part?['article'] ?? '');
    final nameController = TextEditingController(text: part?['name'] ?? '');
    final priceController = TextEditingController(text: part?['price']?.toString() ?? '');
    final descriptionController = TextEditingController(text: part?['description'] ?? '');
    String category = part?['category'] ?? 'Расходные материалы';
    List<String> compatibleModels = List<String>.from(part?['compatible_models'] ?? []);
    // Фотографии: пока храним URL-строки
    List<String> photoUrls = List<String>.from(part?['images'] ?? []);
    final photoUrlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              minChildSize: 0.6,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  padding: EdgeInsets.only(
                    left: 20, right: 20, top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40, height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditing ? 'Редактировать запчасть' : 'Новая запчасть',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // --- Артикул ---
                            _buildInputField(
                              controller: articleController,
                              label: 'Артикул *',
                              icon: Icons.tag,
                            ),
                            const SizedBox(height: 12),

                            // --- Название ---
                            _buildInputField(
                              controller: nameController,
                              label: 'Название *',
                              icon: Icons.label_outline,
                            ),
                            const SizedBox(height: 12),

                            // --- Цена ---
                            _buildInputField(
                              controller: priceController,
                              label: 'Цена (₽) *',
                              icon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 12),

                            // --- Описание ---
                            _buildInputField(
                              controller: descriptionController,
                              label: 'Описание',
                              icon: Icons.description_outlined,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),

                            // --- Категория ---
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButtonFormField<String>(
                                  initialValue: category,
                                  decoration: const InputDecoration(
                                    labelText: 'Категория',
                                    border: InputBorder.none,
                                  ),
                                  items: _categories
                                      .where((c) => c != 'Все')
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => category = val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // --- Совместимые модели (из парка поставщика) ---
                            Row(
                              children: [
                                const Icon(Icons.precision_manufacturing_outlined, size: 18, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 8),
                                const Text('Совместимые модели',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Выберите модели из вашего каталога оборудования',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),

                            if (_availableModels.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Нет моделей в вашем каталоге. Добавьте оборудование через раздел "Оборудование +".',
                                        style: TextStyle(fontSize: 12, color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _availableModels.map((model) {
                                  final isSelected = compatibleModels.contains(model);
                                  return FilterChip(
                                    label: Text(model, style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected ? Colors.white : Colors.black87,
                                    )),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF3B82F6),
                                    checkmarkColor: Colors.white,
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          compatibleModels.add(model);
                                        } else {
                                          compatibleModels.remove(model);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 24),

                            // --- Фотографии ---
                            Row(
                              children: [
                                const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 8),
                                const Text('Фотографии',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Вставьте ссылки на фотографии (Google Drive, Imgur и т.д.)',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),

                            // Превью добавленных фото
                            if (photoUrls.isNotEmpty)
                              ...photoUrls.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final url = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.image_outlined, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          url,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        onPressed: () => setDialogState(() => photoUrls.removeAt(idx)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            // Поле добавления фото
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: photoUrlController,
                                    decoration: InputDecoration(
                                      hintText: 'URL фотографии...',
                                      prefixIcon: const Icon(Icons.link, size: 18),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final url = photoUrlController.text.trim();
                                    if (url.isNotEmpty) {
                                      setDialogState(() {
                                        photoUrls.add(url);
                                        photoUrlController.clear();
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Icon(Icons.add, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // --- Кнопка сохранения ---
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                 onPressed: () async {
                                  if (nameController.text.trim().isEmpty ||
                                      articleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Заполните артикул и название')),
                                    );
                                    return;
                                  }
                                  final data = {
                                    'supplier_id': widget.supplier.id,
                                    'article': articleController.text.trim(),
                                    'name': nameController.text.trim(),
                                    'price': double.tryParse(priceController.text.trim()) ?? 0.0,
                                    'category': category,
                                    'description': descriptionController.text.trim(),
                                    'compatible_models': compatibleModels,
                                    'images': photoUrls,
                                    'in_stock': true,
                                  };

                                  // Показываем лоадер прямо в диалоге
                                  setDialogState(() {});
                                  
                                  try {
                                    if (isEditing) {
                                      data['id'] = part!['id'];
                                      await SupabaseService.updateSparePart(data);
                                    } else {
                                      await SupabaseService.createSparePart(data);
                                    }
                                    // Закрываем только после успешного сохранения
                                    if (context.mounted) Navigator.pop(context);
                                    await _loadData();
                                  } catch (e) {
                                    // Ошибка — показываем сообщение, НЕ закрываем диалог
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Ошибка: $e'),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 6),
                                        ),
                                      );
                                    }
                                    if (mounted) setState(() => _isLoading = false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  isEditing ? 'Сохранить изменения' : 'Добавить запчасть',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredParts = _spareParts.where((part) {
      final matchesSearch =
          part['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              part['article'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'Все' || part['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Мои запчасти'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF3B82F6)),
            onPressed: () => _showAddEditPartDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
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
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((val) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(val),
                        selected: _selectedCategory == val,
                        selectedColor: const Color(0xFF3B82F6).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _selectedCategory == val ? const Color(0xFF3B82F6) : Colors.black87,
                          fontWeight: _selectedCategory == val ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = val);
                        },
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredParts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Нет запчастей',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Нажмите + чтобы добавить первую',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredParts.length,
                        itemBuilder: (context, index) {
                          final part = filteredParts[index];
                          final models = (part['compatible_models'] as List?)?.join(', ') ?? '';
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.build_circle, color: Color(0xFF3B82F6), size: 24),
                              ),
                              title: Text(part['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Арт: ${part['article']} • ${part['price']} ₽'),
                                  if (models.isNotEmpty)
                                    Text(models,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6)),
                                    onPressed: () => _showAddEditPartDialog(part: part),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deletePart(part['id']),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditPartDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
    );
  }
}
