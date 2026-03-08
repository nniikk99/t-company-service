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
    _loadSpareParts();
  }

  Future<void> _loadSpareParts() async {
    setState(() => _isLoading = true);
    try {
      final parts = await SupabaseService.getSupplierSpareParts(widget.supplier.id);
      setState(() {
        _spareParts = parts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки запчастей: $e'), backgroundColor: Colors.red),
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
        await _loadSpareParts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEditPartDialog({Map<String, dynamic>? part}) {
    // Basic dialog for now, to be expanded
    final isEditing = part != null;
    final articleController = TextEditingController(text: part?['article'] ?? '');
    final nameController = TextEditingController(text: part?['name'] ?? '');
    final priceController = TextEditingController(text: part?['price']?.toString() ?? '');
    String category = part?['category'] ?? 'Расходные материалы';
    List<String> compatibleModels = List<String>.from(part?['compatible_models'] ?? []);
    final modelInputController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Редактировать запчасть' : 'Новая запчасть'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: articleController,
                      decoration: const InputDecoration(labelText: 'Артикул'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Цена'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: category,
                      items: _categories.where((c) => c != 'Все').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                      decoration: const InputDecoration(labelText: 'Категория'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Совместимые модели', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...compatibleModels.map((m) => ListTile(
                          title: Text(m),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                compatibleModels.remove(m);
                              });
                            },
                          ),
                        )),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: modelInputController,
                            decoration: const InputDecoration(hintText: 'Напр. Tennant T7'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (modelInputController.text.trim().isNotEmpty) {
                              setDialogState(() {
                                compatibleModels.add(modelInputController.text.trim());
                                modelInputController.clear();
                              });
                            }
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || articleController.text.isEmpty) return;
                    
                    final data = {
                      'supplier_id': widget.supplier.id,
                      'article': articleController.text.trim(),
                      'name': nameController.text.trim(),
                      'price': double.tryParse(priceController.text.trim()) ?? 0.0,
                      'category': category,
                      'compatible_models': compatibleModels,
                    };
                    
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    
                    try {
                      if (isEditing) {
                        data['id'] = part['id'];
                        await SupabaseService.updateSparePart(data);
                      } else {
                        await SupabaseService.createSparePart(data);
                      }
                      await _loadSpareParts();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка сохранения: $e'), backgroundColor: Colors.red),
                        );
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredParts = _spareParts.where((part) {
      final matchesSearch = part['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            part['article'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'Все' || part['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои запчасти'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditPartDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск по артиклу или названию...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: _categories.map((val) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(val),
                  selected: _selectedCategory == val,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = val);
                  },
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredParts.isEmpty 
                  ? const Center(child: Text('Ничего не найдено'))
                  : ListView.builder(
                      itemCount: filteredParts.length,
                      itemBuilder: (context, index) {
                        final part = filteredParts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.build)),
                            title: Text(part['name']),
                            subtitle: Text('Арт: ${part['article']} • ${part['price']} руб.'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showAddEditPartDialog(part: part),
                            ),
                            onLongPress: () => _deletePart(part['id']),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditPartDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
