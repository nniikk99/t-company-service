import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/equipment_model.dart';
import '../services/supabase_service.dart';
import '../data/equipment_specifications.dart';
import 'package:uuid/uuid.dart';

class SupplierEquipmentScreen extends StatefulWidget {
  final User supplier;
  final bool isAdminMode;

  const SupplierEquipmentScreen({
    Key? key, 
    required this.supplier,
    this.isAdminMode = false,
  }) : super(key: key);

  @override
  _SupplierEquipmentScreenState createState() => _SupplierEquipmentScreenState();
}

class _SupplierEquipmentScreenState extends State<SupplierEquipmentScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<EquipmentModel> _models = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    
    List<EquipmentModel> models;
    if (widget.isAdminMode) {
      models = await _supabaseService.getEquipmentModels();
    } else {
      models = await _supabaseService.getSupplierEquipmentModels(widget.supplier.id);
    }
    
    setState(() {
      _models = models;
      _isLoading = false;
    });
  }

  void _showAddModelDialog({EquipmentModel? model}) {
    final manufacturerController = TextEditingController(text: model?.manufacturer);
    final modelController = TextEditingController(text: model?.model);
    final imageUrlController = TextEditingController(text: model?.imageUrl);
    
    // Определяем начальный тип (если редактируем существующий, пытаемся угадать или ставим дефолт)
    String selectedType = 'Поломоечная машина'; 
    final Map<String, TextEditingController> specControllers = {};

    void updateControllers(String type, Map<String, dynamic>? existingSpecs) {
      specControllers.clear();
      final template = EquipmentSpecifications.getTypeTemplate(type);
      template.forEach((key, field) {
        specControllers[key] = TextEditingController(
          text: existingSpecs?[key]?['value']?.toString() ?? '',
        );
      });
    }

    updateControllers(selectedType, model?.specifications);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(model == null ? 'Создать модель' : 'Редактировать модель'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextField(
                      controller: manufacturerController,
                      decoration: const InputDecoration(
                        labelText: 'Производитель',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextField(
                      controller: modelController,
                      decoration: const InputDecoration(
                        labelText: 'Модель',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextField(
                      controller: imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL изображения (опционально)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Тип оборудования',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: EquipmentSpecifications.getEquipmentTypes().map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          updateControllers(selectedType, model?.specifications);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Технические характеристики', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ...specControllers.entries.map((entry) {
                    final template = EquipmentSpecifications.getTypeTemplate(selectedType);
                    final field = template[entry.key];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: field['label'],
                          suffixText: field['unit'],
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                final template = EquipmentSpecifications.getTypeTemplate(selectedType);
                Map<String, dynamic> specs = {};
                specControllers.forEach((key, controller) {
                  if (controller.text.isNotEmpty) {
                    specs[key] = {
                      'value': controller.text,
                      'unit': template[key]['unit'] ?? '',
                      'label': template[key]['label'],
                    };
                  }
                });

                final newModel = EquipmentModel(
                  id: model?.id ?? const Uuid().v4(),
                  supplierId: model?.supplierId ?? widget.supplier.id,
                  manufacturer: manufacturerController.text,
                  model: modelController.text,
                  imageUrl: imageUrlController.text,
                  specifications: specs,
                  createdAt: model?.createdAt ?? DateTime.now(),
                );

                if (model == null) {
                  await _supabaseService.createEquipmentModel(newModel);
                } else {
                  await _supabaseService.updateEquipmentModel(newModel);
                }
                Navigator.pop(context);
                _loadModels();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdminMode ? 'Все оборудование' : 'Оборудование +'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadModels),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _models.isEmpty
              ? const Center(child: Text('У вас пока нет созданных моделей'))
              : ListView.builder(
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    return ListTile(
                      leading: model.imageUrl != null 
                          ? Image.network(model.imageUrl!, width: 50, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))
                          : const Icon(Icons.image),
                      title: Text(model.fullTitle),
                      subtitle: Text('Характеристик: ${model.specifications.length}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _showAddModelDialog(model: model)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Удаление'),
                                  content: const Text('Удалить эту модель?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _supabaseService.deleteEquipmentModel(model.id);
                                _loadModels();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddModelDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
