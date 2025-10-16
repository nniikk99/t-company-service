import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/equipment.dart';
import '../models/user.dart';
import '../models/site.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../widgets/error_dialog.dart';

class EditEquipmentDialog extends StatefulWidget {
  final User user;
  final Equipment equipment;
  final Function onEquipmentUpdated;

  const EditEquipmentDialog({
    super.key,
    required this.user,
    required this.equipment,
    required this.onEquipmentUpdated,
  });

  @override
  State<EditEquipmentDialog> createState() => _EditEquipmentDialogState();
}

class _EditEquipmentDialogState extends State<EditEquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serialNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();

  String _selectedManufacturer = '';
  String _selectedModel = '';
  String _selectedModification = '';
  String _selectedSiteId = '';
  EquipmentStatus _selectedStatus = EquipmentStatus.active;

  List<Site> _availableSites = [];
  bool _isLoadingSites = true;

  @override
  void initState() {
    super.initState();
    _serialNumberController.text = widget.equipment.serialNumber ?? '';
    _descriptionController.text = widget.equipment.description ?? '';
    _locationController.text = widget.equipment.location ?? '';
    _addressController.text = widget.equipment.address ?? '';

    _selectedManufacturer = widget.equipment.manufacturer;
    _selectedModel = widget.equipment.model;
    _selectedModification = widget.equipment.modification ?? '';
    _selectedSiteId = widget.equipment.siteId ?? '';
    _selectedStatus = widget.equipment.status;

    _loadSites();
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoadingSites = true);
    try {
      final supabaseSites = await SupabaseService.getSites(widget.user.companyId ?? '');
      _availableSites = supabaseSites;
      
      // Проверяем, есть ли текущая площадка в списке доступных
      if (_selectedSiteId.isNotEmpty && !_availableSites.any((site) => site.id == _selectedSiteId)) {
        print('⚠️ Площадка $_selectedSiteId не найдена в доступных площадках');
        _selectedSiteId = ''; // Сбрасываем, если площадка не найдена
      }
    } catch (e) {
      print('Supabase error loading sites: $e');
      _availableSites = await StorageService.getSites(companyId: widget.user.companyId);
      
      // Проверяем, есть ли текущая площадка в списке доступных
      if (_selectedSiteId.isNotEmpty && !_availableSites.any((site) => site.id == _selectedSiteId)) {
        print('⚠️ Площадка $_selectedSiteId не найдена в доступных площадках');
        _selectedSiteId = ''; // Сбрасываем, если площадка не найдена
      }
    } finally {
      setState(() => _isLoadingSites = false);
    }
  }

  Future<void> _updateEquipment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedManufacturer.isEmpty || _selectedModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите производителя и модель')),
      );
      return;
    }
    if (_selectedSiteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите площадку для оборудования')),
      );
      return;
    }

    setState(() => _isLoadingSites = true); // Re-using for general loading state

    try {
      final updatedEquipment = widget.equipment.copyWith(
        name: '${_selectedManufacturer} ${_selectedModel}${_selectedModification.isNotEmpty ? ' ${_selectedModification}' : ''}',
        manufacturer: _selectedManufacturer,
        model: _selectedModel,
        modification: _selectedModification.isNotEmpty ? _selectedModification : null,
        serialNumber: _serialNumberController.text.trim().isNotEmpty
            ? _serialNumberController.text.trim() : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim() : null,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim() : null,
        siteId: _selectedSiteId.isNotEmpty ? _selectedSiteId : null,
        status: _selectedStatus,
        updatedAt: DateTime.now(),
      );

      await SupabaseService.updateEquipment(updatedEquipment);
      await StorageService.updateEquipment(updatedEquipment);

      if (mounted) {
        widget.onEquipmentUpdated();
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error updating equipment: $e');
      if (mounted) {
        ErrorDialog.show(
          context: context,
          title: 'Ошибка обновления',
          message: 'Не удалось обновить оборудование: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSites = false);
      }
    }
  }

  Future<void> _deleteEquipment() async {
    try {
      await SupabaseService.deleteEquipment(widget.equipment.id);
      await StorageService.deleteEquipment(widget.equipment.id);

      if (mounted) {
        widget.onEquipmentUpdated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оборудование успешно удалено')),
        );
      }
    } catch (e) {
      print('Error deleting equipment: $e');
      if (mounted) {
        ErrorDialog.show(
          context: context,
          title: 'Ошибка удаления',
          message: 'Не удалось удалить оборудование: ${e.toString()}',
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить оборудование?'),
        content: Text('Вы уверены, что хотите удалить оборудование "${widget.equipment.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close confirmation dialog
              await _deleteEquipment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Редактировать оборудование',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Производитель
              const Text(
                'Производитель',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedManufacturer.isNotEmpty && 
                       ['Gadlee', 'Karcher', 'Tennant', 'Nilfisk', 'Comac'].contains(_selectedManufacturer) 
                       ? _selectedManufacturer : null,
                decoration: InputDecoration(
                  hintText: 'Выберите производителя',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: ['Gadlee', 'Karcher', 'Tennant', 'Nilfisk', 'Comac']
                    .map((manufacturer) => DropdownMenuItem(
                          value: manufacturer,
                          child: Text(manufacturer),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedManufacturer = value ?? '';
                    _selectedModel = ''; // Reset model when manufacturer changes
                    _selectedModification = ''; // Reset modification
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 20),

              // Модель
              const Text(
                'Модель',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedModel.isNotEmpty && 
                       _getModelsForManufacturer(_selectedManufacturer).contains(_selectedModel)
                       ? _selectedModel : null,
                decoration: InputDecoration(
                  hintText: 'Выберите модель',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _getModelsForManufacturer(_selectedManufacturer)
                    .map((model) => DropdownMenuItem(
                          value: model,
                          child: Text(model),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedModel = value ?? '';
                    _selectedModification = ''; // Reset modification
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 20),

              // Модификация (опционально)
              const Text(
                'Модификация (опционально)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedModification.isNotEmpty && 
                       _getModificationsForModel(_selectedModel).contains(_selectedModification)
                       ? _selectedModification : null,
                decoration: InputDecoration(
                  hintText: 'Выберите модификацию',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _getModificationsForModel(_selectedModel)
                    .map((modification) => DropdownMenuItem(
                          value: modification,
                          child: Text(modification),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedModification = value ?? '';
                  });
                },
              ),
              const SizedBox(height: 20),

              // Серийный номер
              const Text(
                'Серийный номер',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _serialNumberController,
                decoration: InputDecoration(
                  hintText: 'Введите серийный номер',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Площадка
              const Text(
                'Площадка',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingSites
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedSiteId.isNotEmpty && 
                             _availableSites.any((site) => site.id == _selectedSiteId)
                             ? _selectedSiteId : null,
                      decoration: InputDecoration(
                        hintText: 'Выберите площадку',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _availableSites
                          .map((site) => DropdownMenuItem(
                                value: site.id,
                                child: Text(site.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSiteId = value ?? '';
                        });
                      },
                      validator: (value) => value == null || value.isEmpty ? 'Обязательное поле' : null,
                    ),
              const SizedBox(height: 20),

              // Местоположение
              const Text(
                'Местоположение (опционально)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'Введите местоположение',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Адрес
              const Text(
                'Адрес (опционально)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'Введите адрес',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Статус
              const Text(
                'Статус',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<EquipmentStatus>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  hintText: 'Выберите статус',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: EquipmentStatus.values
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(_getEquipmentStatusText(status)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value ?? EquipmentStatus.active;
                  });
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _showDeleteConfirmation,
          child: const Text('Удалить', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _isLoadingSites ? null : _updateEquipment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isLoadingSites
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }

  List<String> _getModelsForManufacturer(String manufacturer) {
    switch (manufacturer) {
      case 'Gadlee':
        return ['GT55', 'GT70', 'GT110', 'GT30', 'GT50'];
      case 'Karcher':
        return ['BD 50/50 C Bp Classic', 'B 40 C Bp', 'BR 30/4 C Bp'];
      case 'Tennant':
        return ['T7', 'T300', 'T500', 'CS5'];
      case 'Nilfisk':
        return ['SC401', 'SC500', 'SC6000'];
      case 'Comac':
        return ['Vispa 35 B', 'Abila 50 B', 'Innova 60 B'];
      default:
        return [];
    }
  }

  List<String> _getModificationsForModel(String model) {
    switch (model) {
      case 'GT55':
        return ['Standard', 'Pro'];
      case 'GT70':
        return ['Basic', 'Advanced'];
      case 'GT110':
        return ['Li-Ion', 'Gel'];
      case 'GT30':
        return ['Standard', 'Pro'];
      case 'T7':
        return ['Standard', 'Pro'];
      case 'BD 50/50 C Bp Classic':
        return ['Basic', 'Advanced'];
      default:
        return [];
    }
  }

  String _getEquipmentStatusText(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return 'Активно';
      case EquipmentStatus.maintenance:
        return 'На обслуживании';
      case EquipmentStatus.inactive:
        return 'Неактивно';
      case EquipmentStatus.broken:
        return 'Сломано';
      default:
        return 'Неизвестно';
    }
  }
}
