import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/equipment.dart';
import '../models/site.dart';
import '../models/user.dart';
import '../models/equipment_model.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';

class AddEquipmentDialog extends StatefulWidget {
  final User user;
  final Function(Equipment)? onEquipmentAdded;

  const AddEquipmentDialog({
    super.key,
    required this.user,
    this.onEquipmentAdded,
  });

  @override
  State<AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends State<AddEquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serialNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingSites = false;
  
  List<Site> _sites = [];
  List<EquipmentModel> _availableModels = [];
  EquipmentModel? _selectedModelObj;
  String _selectedSiteId = '';
  DateTime? _purchaseDate;
  
  // Убираем хардкодные данные производителей

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSites(),
      _loadModels(),
    ]);
  }

  Future<void> _loadModels() async {
    final models = await SupabaseService().getEquipmentModels();
    setState(() => _availableModels = models);
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoadingSites = true);
    try {
      print('🔍 Загружаем площадки для компании с ИНН: ${widget.user.companyInn}');
      print('🔍 ID пользователя: ${widget.user.id}');
      print('🔍 Имя пользователя: ${widget.user.fullName}');
      print('🔍 Роль пользователя: ${widget.user.role}');
      // Загружаем площадки только для текущей компании
      final sites = await StorageService.getSites(companyId: widget.user.companyId);
      print('📋 Найдено площадок: ${sites.length}');
      for (var site in sites) {
        print('  - ${site.name} (ИНН: ${site.companyInn})');
      }
      setState(() => _sites = sites);
    } catch (e) {
      print('❌ Ошибка загрузки площадок: $e');
      // Fallback to local storage
      try {
        final localSites = await StorageService.getSites();
        print('📋 Fallback - найдено площадок: ${localSites.length}');
        setState(() => _sites = localSites);
      } catch (e) {
        print('❌ Ошибка fallback загрузки площадок: $e');
      }
    } finally {
      setState(() => _isLoadingSites = false);
    }
  }

  Future<void> _saveEquipment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedModelObj == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите модель оборудования')),
      );
      return;
    }
    if (_selectedSiteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите площадку для оборудования')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Найти выбранную площадку
      Site? selectedSite;
      if (_selectedSiteId.isNotEmpty) {
        selectedSite = _sites.firstWhere((site) => site.id == _selectedSiteId);
      }

      final equipment = Equipment(
        id: const Uuid().v4(),
        clientId: widget.user.companyId,
        companyId: widget.user.companyId,
        companyInn: widget.user.companyInn,
        name: '${_selectedModelObj!.manufacturer} ${_selectedModelObj!.model}',
        manufacturer: _selectedModelObj!.manufacturer,
        model: _selectedModelObj!.model,
        modification: null,
        serialNumber: _serialNumberController.text.trim().isNotEmpty 
            ? _serialNumberController.text.trim() : null,
        siteId: _selectedSiteId.isNotEmpty ? _selectedSiteId : null,
        location: selectedSite?.name ?? 'Не указана',
        address: selectedSite?.address ?? '',
        status: EquipmentStatus.active,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() : null,
        createdAt: DateTime.now(),
        type: _selectedModelObj!.specifications['type']?.toString() ?? 'Поломоечная машина',
        purchaseDate: _purchaseDate,
        specifications: _selectedModelObj!.specifications,
        imageUrl: _selectedModelObj!.imageUrl,
        responsibleUserId: widget.user.id, // Назначаем создателя ответственным за оборудование
      );

      // Сохранить в Supabase и локально
      bool supabaseSaved = false;
      String? supabaseError;
      
      try {
        print('🔍 Попытка создания оборудования:');
        print('  - User ID: ${widget.user.id}');
        print('  - User Role: ${widget.user.role}');
        print('  - Company ID: ${widget.user.companyId}');
        print('  - Company INN: ${widget.user.companyInn}');
        print('  - Equipment data: ${equipment.toJson()}');
        
        await SupabaseService.createEquipment(equipment);
        supabaseSaved = true;
        print('✅ Equipment saved to Supabase successfully');
      } catch (e) {
        supabaseError = e.toString();
        print('❌ Supabase error: $e');
        print('❌ Error details: ${e.runtimeType}');
      }
      
      // Всегда сохраняем локально
      await StorageService.saveEquipment(equipment);

      if (widget.onEquipmentAdded != null) {
        widget.onEquipmentAdded!(equipment);
      }

      Navigator.of(context).pop();
      
      // Показываем результат с учетом статуса синхронизации
      if (supabaseSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Оборудование успешно добавлено и синхронизировано!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ Оборудование сохранено локально'),
                Text('Ошибка синхронизации: ${supabaseError ?? "неизвестная"}', 
                     style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _selectPurchaseDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // Убираем locale если нет уверенности в инициализации Intl
    );
    if (picked != null && picked != _purchaseDate) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C7CE7), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.precision_manufacturing,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Добавить оборудование',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic height
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = screenHeight - keyboardHeight - 100;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: 600,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Серийный номер
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Выбор модели оборудования (от поставщика)
                        const Text(
                          'Модель оборудования',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<EquipmentModel>(
                          initialValue: _selectedModelObj,
                          decoration: InputDecoration(
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
                          hint: const Text('Выберите модель'),
                          items: _availableModels.map<DropdownMenuItem<EquipmentModel>>((model) {
                            return DropdownMenuItem<EquipmentModel>(
                              value: model,
                              child: Text('${model.manufacturer} ${model.model}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedModelObj = value;
                            });
                          },
                          validator: (value) => value == null 
                              ? 'Пожалуйста, выберите модель' : null,
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
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSiteId.isNotEmpty ? _selectedSiteId : null,
                          decoration: InputDecoration(
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
                          hint: Text(_isLoadingSites ? 'Загрузка...' : 'Выберите площадку'),
                          items: _sites.map<DropdownMenuItem<String>>((site) {
                            return DropdownMenuItem<String>(
                              value: site.id,
                              child: Text(site.name),
                            );
                          }).toList(),
                          onChanged: !_isLoadingSites ? (value) {
                            setState(() {
                              _selectedSiteId = value ?? '';
                            });
                          } : null,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        const SizedBox(height: 20),
                        
                        // Дата реализации
                        const Text(
                          'Дата реализации (покупки)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _selectPurchaseDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                                const SizedBox(width: 12),
                                Text(
                                  _purchaseDate == null 
                                      ? 'Выберите дату' 
                                      : '${_purchaseDate!.day}.${_purchaseDate!.month}.${_purchaseDate!.year}',
                                  style: TextStyle(
                                    color: _purchaseDate == null ? Colors.grey[600] : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Описание
                        const Text(
                          'Описание',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Дополнительная информация об оборудовании',
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
                        
                        const SizedBox(height: 32),
                        
                        // Кнопки
                        Column(
                          children: [
                            // Синяя кнопка сверху
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveEquipment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Добавить оборудование',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Кнопка отмены снизу
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                                child: const Text(
                                  'Отмена',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
