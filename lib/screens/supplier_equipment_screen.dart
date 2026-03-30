import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../models/equipment_model.dart';
import '../services/supabase_service.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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
      builder: (context) {
        Uint8List? selectedImageBytes;
        bool isUploading = false;
        
        return StatefulBuilder(
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
                    
                    // --- Изображение ---
                    const SizedBox(height: 16),
                    const Text('Изображение оборудования', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedImageBytes != null || imageUrlController.text.isNotEmpty)
                          Container(
                            height: 150,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: selectedImageBytes != null 
                                ? Image.memory(selectedImageBytes!, fit: BoxFit.contain)
                                : Image.network(imageUrlController.text, fit: BoxFit.contain, errorBuilder: (ctx, err, _) => const Icon(Icons.image_not_supported)),
                            ),
                          ),
                        
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final image = await picker.pickImage(source: ImageSource.gallery);
                                  if (image != null) {
                                    final bytes = await image.readAsBytes();
                                    setDialogState(() {
                                      selectedImageBytes = bytes;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Загрузить фото'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                                  foregroundColor: const Color(0xFF3B82F6),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            if (selectedImageBytes != null)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => setDialogState(() => selectedImageBytes = null),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Или вставьте URL изображения',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ... документация и характеристики
                    const Text('Документация', style: TextStyle(fontWeight: FontWeight.bold)),
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
                onPressed: isUploading ? null : () async {
                  if (maintenanceMonthsController.text.trim().isEmpty || maintenanceHoursController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Пожалуйста, заполните поля периодичности ТО'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  setDialogState(() => isUploading = true);
                  
                  try {
                    String finalImageUrl = imageUrlController.text.trim();
                    
                    if (selectedImageBytes != null) {
                      final uploadedUrl = await SupabaseService.uploadEquipmentModelPhoto(
                        widget.supplier.id,
                        selectedImageBytes!,
                        'model_image.jpg'
                      );
                      if (uploadedUrl != null) {
                        finalImageUrl = uploadedUrl;
                      }
                    }

                    Map<String, dynamic> finalSpecs = {};
                    if (instructionUrlController.text.trim().isNotEmpty) finalSpecs['_instruction_url'] = instructionUrlController.text.trim();
                    if (manualUrlController.text.trim().isNotEmpty) finalSpecs['_manual_url'] = manualUrlController.text.trim();
                    finalSpecs['_maintenance_months'] = maintenanceMonthsController.text.trim();
                    finalSpecs['_maintenance_hours'] = maintenanceHoursController.text.trim();

                    int validSpecIndex = 0;
                    for (int i = 0; i < specLabelControllers.length; i++) {
                      final label = specLabelControllers[i].text.trim();
                      final value = specValueControllers[i].text.trim();
                      if (label.isNotEmpty && value.isNotEmpty) {
                        finalSpecs['spec_$validSpecIndex'] = {'label': label, 'value': value, 'unit': ''};
                        validSpecIndex++;
                      }
                    }

                    final updatedModel = EquipmentModel(
                      id: model?.id ?? const Uuid().v4(),
                      supplierId: model?.supplierId ?? widget.supplier.id,
                      manufacturer: manufacturerController.text,
                      model: modelController.text,
                      imageUrl: finalImageUrl,
                      specifications: finalSpecs,
                      createdAt: model?.createdAt ?? DateTime.now(),
                    );

                    if (model == null) {
                      await _supabaseService.createEquipmentModel(updatedModel);
                    } else {
                      await _supabaseService.updateEquipmentModel(updatedModel);
                    }

                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
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
                        ),
                      );
                    }
                  } finally {
                    setDialogState(() => isUploading = false);
                  }
                },
                child: isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelCard(EquipmentModel model) {
    // Считаем количество заполненных характеристик (исключая служебные поля с _)
    int specsCount = model.specifications.keys.where((k) => !k.startsWith('_')).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddModelDialog(model: model),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Изображение
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: model.imageUrl != null && model.imageUrl!.isNotEmpty
                        ? Image.network(
                            model.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                          )
                        : const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                // Информация
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.fullTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Характеристик: $specsCount',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Действия
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 22),
                      onPressed: () => _showAddModelDialog(model: model),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      onPressed: () => _deleteModel(model),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteModel(EquipmentModel model) async {
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
              content: Text('Ошибка удаления: $e', style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.isAdminMode ? 'Все оборудование' : 'Оборудование +'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadModels),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _models.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('У вас пока нет созданных моделей', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    return _buildModelCard(_models[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddModelDialog(),
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
