import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../models/equipment_model.dart';
import '../services/supabase_service.dart';
import '../services/image_service.dart';
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

  // Поиск и UI-состояния
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  final Set<String> _collapsed = <String>{}; // свёрнутые производители

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Фильтрация и группировка ───────────────────────────────────────────

  List<EquipmentModel> get _filteredModels {
    if (_search.isEmpty) return _models;
    final q = _search.toLowerCase();
    return _models.where((m) {
      return m.manufacturer.toLowerCase().contains(q) ||
          m.model.toLowerCase().contains(q) ||
          m.fullTitle.toLowerCase().contains(q);
    }).toList();
  }

  /// Группировка: {manufacturer: [model, ...]}, отсортировано по алфавиту.
  Map<String, List<EquipmentModel>> get _grouped {
    final map = <String, List<EquipmentModel>>{};
    for (final m in _filteredModels) {
      final key = m.manufacturer.isEmpty ? 'Без бренда' : m.manufacturer;
      map.putIfAbsent(key, () => []).add(m);
    }
    // сортировка моделей внутри группы по названию
    for (final list in map.values) {
      list.sort((a, b) => a.model.toLowerCase().compareTo(b.model.toLowerCase()));
    }
    return Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
  }

  // Подсчёт полезных бейджей для модели
  int _specsCount(EquipmentModel m) =>
      m.specifications.keys.where((k) => !k.startsWith('_')).length;

  bool _hasManual(EquipmentModel m) =>
      (m.specifications['_manual_url'] ?? '').toString().isNotEmpty;
  bool _hasInstruction(EquipmentModel m) =>
      (m.specifications['_instruction_url'] ?? '').toString().isNotEmpty;
  bool _hasMaintenance(EquipmentModel m) =>
      (m.specifications['_maintenance_months'] ?? '').toString().isNotEmpty ||
      (m.specifications['_maintenance_hours'] ?? '').toString().isNotEmpty;

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

  /// Рендер фото модели с цепочкой fallback'ов:
  /// 1) URL фото, загруженный поставщиком (model.imageUrl)
  /// 2) Локальный asset по производитель+модель (как видит клиент)
  /// 3) Градиентная заглушка с иконкой
  Widget _modelImage(EquipmentModel model) {
    // 1. Загруженное в БД фото
    final url = model.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _localAssetImage(model),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _imagePlaceholder(),
      );
    }
    // 2. Локальный ассет (или 3. заглушка внутри _localAssetImage)
    return _localAssetImage(model);
  }

  /// Пытается показать локальный ассет по (manufacturer, model).
  /// Если ассета нет — fallback на градиентную заглушку.
  Widget _localAssetImage(EquipmentModel model) {
    if (model.manufacturer.isEmpty || model.model.isEmpty) {
      return _imagePlaceholder();
    }
    final paths = ImageService.getPossibleImagePaths(
      model.manufacturer,
      model.model,
    );
    if (paths.isEmpty) return _imagePlaceholder();
    return Image.asset(
      paths.first,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imagePlaceholder(),
    );
  }

  /// Заглушка для отсутствующего фото — градиент + иконка.
  Widget _imagePlaceholder({double size = 72}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.precision_manufacturing_rounded,
          color: Color(0xFF93C5FD), size: 32),
    );
  }

  /// Маленький бейдж под названием модели.
  Widget _miniBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildModelCard(EquipmentModel model) {
    final specs = _specsCount(model);
    final hasManual = _hasManual(model);
    final hasInstr = _hasInstruction(model);
    final hasMnt = _hasMaintenance(model);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddModelDialog(model: model),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Фото 72×72.
                // Приоритет: imageUrl из БД → локальный ассет (как у клиента) → градиент.
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: _modelImage(model),
                  ),
                ),
                const SizedBox(width: 14),
                // Информация
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        model.manufacturer.isNotEmpty
                            ? model.manufacturer.toUpperCase()
                            : 'БРЕНД НЕ ЗАДАН',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.model.isNotEmpty
                            ? model.model
                            : '— без названия —',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Бейджи
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _miniBadge(Icons.list_alt_rounded, '$specs х-к',
                              const Color(0xFF3B82F6)),
                          if (hasMnt)
                            _miniBadge(Icons.event_repeat_rounded, 'ТО',
                                const Color(0xFF16A34A)),
                          if (hasManual)
                            _miniBadge(Icons.menu_book_rounded, 'Мануал',
                                const Color(0xFF8B5CF6)),
                          if (hasInstr)
                            _miniBadge(Icons.description_outlined,
                                'Инструкция', const Color(0xFFEA580C)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Меню действий
                _actionMenu(model),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionMenu(EquipmentModel model) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') _showAddModelDialog(model: model);
        if (value == 'delete') _deleteModel(model);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 10),
              Text('Редактировать'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Удалить',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupHeader(String manufacturer, int count) {
    final collapsed = _collapsed.contains(manufacturer);
    return InkWell(
      onTap: () {
        setState(() {
          if (collapsed) {
            _collapsed.remove(manufacturer);
          } else {
            _collapsed.add(manufacturer);
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.business_rounded,
                  size: 18, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                manufacturer,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: collapsed ? -0.25 : 0,
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF94A3B8)),
            ),
          ],
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
    final filtered = _filteredModels;
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isAdminMode ? 'Каталог техники' : 'Модели техники',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                )),
            if (!_isLoading)
              Text(
                _models.isEmpty
                    ? 'Ничего не добавлено'
                    : '${_models.length} ${_modelsWord(_models.length)} · '
                        '${grouped.length} ${_brandsWord(grouped.length)}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            tooltip: 'Обновить',
            onPressed: _loadModels,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Поиск по модели или производителю',
                  hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF94A3B8), size: 20),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF94A3B8), size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _models.isEmpty
              ? _buildEmptyState(
                  icon: Icons.precision_manufacturing_outlined,
                  title: 'Нет моделей техники',
                  subtitle: 'Добавьте первую модель — заполните характеристики,\nприкрепите мануал и инструкцию',
                  cta: 'Добавить модель',
                )
              : filtered.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Ничего не найдено',
                      subtitle: 'Попробуйте изменить запрос',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      children: [
                        for (final entry in grouped.entries) ...[
                          _groupHeader(entry.key, entry.value.length),
                          if (!_collapsed.contains(entry.key))
                            ...entry.value.map(_buildModelCard),
                        ],
                      ],
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddModelDialog(),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить модель',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? cta,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
                ),
                borderRadius: BorderRadius.circular(48),
              ),
              child: Icon(icon, size: 44, color: const Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                )),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5),
            ),
            if (cta != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showAddModelDialog(),
                icon: const Icon(Icons.add_rounded),
                label: Text(cta,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _modelsWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'модель';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'модели';
    }
    return 'моделей';
  }

  String _brandsWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'бренд';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'бренда';
    }
    return 'брендов';
  }
}
