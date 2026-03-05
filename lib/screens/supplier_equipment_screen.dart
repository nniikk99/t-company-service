import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../models/equipment_model.dart';
import '../services/supabase_service.dart';
import 'package:uuid/uuid.dart';

class SupplierEquipmentScreen extends StatefulWidget {
  final User supplier;
  final bool isAdminMode;

  const SupplierEquipmentScreen({
    super.key, 
    required this.supplier,
    this.isAdminMode = false,
  });

  @override
  _SupplierEquipmentScreenState createState() => _SupplierEquipmentScreenState();
}

class _SupplierEquipmentScreenState extends State<SupplierEquipmentScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<EquipmentModel> _models = [];
  List<String> _approvedBrands = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('equipment_brands')
          .select()
          .eq('supplier_id', widget.supplier.id)
          .eq('status', 'approved');
      
      _approvedBrands = (response as List).map((e) => e['name'] as String).toList();
    } catch (e) {
      print('Ошибка загрузки брендов: $e');
    }

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
    
    List<TextEditingController> specLabelControllers = [];
    List<TextEditingController> specValueControllers = [];

    final instructionUrlController = TextEditingController();
    final manualUrlController = TextEditingController();
    
    final maintenanceMonthsController = TextEditingController();
    final maintenanceHoursController = TextEditingController();

    if (model != null && model.specifications.isNotEmpty) {
      if (model.specifications.containsKey('_instruction_url')) {
        instructionUrlController.text = model.specifications['_instruction_url'];
      }
      if (model.specifications.containsKey('_manual_url')) {
        manualUrlController.text = model.specifications['_manual_url'];
      }
      if (model.specifications.containsKey('_maintenance_months')) {
        maintenanceMonthsController.text = model.specifications['_maintenance_months'].toString();
      }
      if (model.specifications.containsKey('_maintenance_hours')) {
        maintenanceHoursController.text = model.specifications['_maintenance_hours'].toString();
      }
      
      model.specifications.forEach((key, data) {
        if (!key.startsWith('_') && data is Map && data.containsKey('label') && data.containsKey('value')) {
          specLabelControllers.add(TextEditingController(text: data['label']?.toString() ?? ''));
          specValueControllers.add(TextEditingController(text: data['value']?.toString() ?? ''));
        }
      });
    }

    // Ensure at least 2 characteristics by default
    while (specLabelControllers.length < 2) {
      specLabelControllers.add(TextEditingController());
      specValueControllers.add(TextEditingController());
    }

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
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _approvedBrands.isEmpty 
                    ? const Text('У вас нет одобренных товарных знаков. Пожалуйста, добавьте их в разделе "Товарный знак".', style: TextStyle(color: Colors.red))
                    : DropdownButtonFormField<String>(
                        value: _approvedBrands.contains(manufacturerController.text) ? manufacturerController.text : null,
                        decoration: const InputDecoration(
                          labelText: 'Производитель',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: _approvedBrands.map((brand) {
                          return DropdownMenuItem(value: brand, child: Text(brand));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            manufacturerController.text = value;
                          }
                        },
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
                  const Text('Документация (прямая ссылка или Google Диск)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextField(
                      controller: instructionUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Инструкция по эксплуатации (URL)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TextField(
                      controller: manualUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Мануал (URL)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Периодичность технического обслуживания *', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: maintenanceMonthsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'В месяцах (напр. 3)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: maintenanceHoursController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'В моточасах (напр. 500)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Технические характеристики', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.transparent, // Для корректного drag-and-drop фона
                    ),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: specLabelControllers.length,
                      onReorder: (int oldIndex, int newIndex) {
                        setDialogState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final labelItem = specLabelControllers.removeAt(oldIndex);
                          final valueItem = specValueControllers.removeAt(oldIndex);
                          specLabelControllers.insert(newIndex, labelItem);
                          specValueControllers.insert(newIndex, valueItem);
                        });
                      },
                      itemBuilder: (context, index) {
                        final isMobile = MediaQuery.of(context).size.width < 600;
                        return Container(
                          key: ValueKey(specLabelControllers[index]),
                          margin: const EdgeInsets.only(bottom: 12.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.center,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 12.0),
                                  child: Icon(Icons.drag_indicator, color: Colors.grey),
                                ),
                              ),
                              Expanded(
                                child: isMobile
                                    ? Column(
                                        children: [
                                          TextField(
                                            controller: specLabelControllers[index],
                                            decoration: InputDecoration(
                                              labelText: 'Название х-ки ${index + 1}',
                                              border: const OutlineInputBorder(),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: specValueControllers[index],
                                            decoration: const InputDecoration(
                                              labelText: 'Значение',
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: specLabelControllers[index],
                                              decoration: InputDecoration(
                                                labelText: 'Название х-ки ${index + 1}',
                                                border: const OutlineInputBorder(),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: specValueControllers[index],
                                              decoration: const InputDecoration(
                                                labelText: 'Значение',
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setDialogState(() {
                                    specLabelControllers[index].dispose();
                                    specValueControllers[index].dispose();
                                    specLabelControllers.removeAt(index);
                                    specValueControllers.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (specLabelControllers.length < 50)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            specLabelControllers.add(TextEditingController());
                            specValueControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Добавить характеристику'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (maintenanceMonthsController.text.trim().isEmpty || maintenanceHoursController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пожалуйста, заполните поля периодичности ТО'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Map<String, dynamic> specs = {};
                
                if (instructionUrlController.text.trim().isNotEmpty) {
                  specs['_instruction_url'] = instructionUrlController.text.trim();
                }
                if (manualUrlController.text.trim().isNotEmpty) {
                  specs['_manual_url'] = manualUrlController.text.trim();
                }
                
                specs['_maintenance_months'] = maintenanceMonthsController.text.trim();
                specs['_maintenance_hours'] = maintenanceHoursController.text.trim();

                int validSpecIndex = 0;
                for (int i = 0; i < specLabelControllers.length; i++) {
                  final label = specLabelControllers[i].text.trim();
                  final value = specValueControllers[i].text.trim();
                  if (label.isNotEmpty && value.isNotEmpty) {
                    specs['spec_$validSpecIndex'] = {
                      'label': label,
                      'value': value,
                      'unit': '',
                    };
                    validSpecIndex++;
                  }
                }

                final newModel = EquipmentModel(
                  id: model?.id ?? const Uuid().v4(),
                  supplierId: model?.supplierId ?? widget.supplier.id,
                  manufacturer: manufacturerController.text,
                  model: modelController.text,
                  imageUrl: imageUrlController.text,
                  specifications: specs,
                  createdAt: model?.createdAt ?? DateTime.now(),
                );

                try {
                  if (model == null) {
                    await _supabaseService.createEquipmentModel(newModel);
                  } else {
                    await _supabaseService.updateEquipmentModel(newModel);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Успешно сохранено'), backgroundColor: Colors.green),
                    );
                  }
                  _loadModels();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ошибка сохранения: $e', style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
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
                                try {
                                  await SupabaseService.deleteEquipmentModel(model.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Модель успешно удалена'), backgroundColor: Colors.green),
                                    );
                                  }
                                  _loadModels();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Ошибка удаления. Возможно, модель используется: $e', style: const TextStyle(fontSize: 12)),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                }
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
