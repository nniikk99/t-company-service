import 'package:flutter/material.dart';
import '../models/user.dart';
import 'package:uuid/uuid.dart';
import '../models/equipment.dart';
import '../models/site.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_navigation.dart';
import '../widgets/iframe_view_d.dart';
import '../widgets/add_site_dialog.dart';
import '../widgets/edit_equipment_dialog.dart';
import '../widgets/equipment_specifications_widget.dart';
import '../widgets/equipment_maintenance_widget.dart';

class EquipmentListScreen extends StatefulWidget {
  final User user;
  final VoidCallback? onAddEquipment;
  final VoidCallback? onAddSite;
  final Function(String)? onServiceClick;
  final Function(Equipment)? onPartsClick;
  final Function(String)? onViewDetails;

  const EquipmentListScreen({
    super.key, 
    required this.user,
    this.onAddEquipment,
    this.onAddSite,
    this.onServiceClick,
    this.onPartsClick,
    this.onViewDetails,
  });

  @override
  State<EquipmentListScreen> createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends State<EquipmentListScreen> {
  List<Equipment> _equipment = [];
  bool _isLoading = true;
  String? _selectedLocation;
  String? _selectedModel;

  List<String> _locations = ['Все площадки'];
  List<Site> _sites = [];

  List<String> _models = ['Все модели']; // Динамический список моделей

  @override
  void initState() {
    super.initState();
    _selectedLocation = 'Все площадки';
    _selectedModel = 'Все модели';
    _loadSites();
    _loadEquipment();
  }

  void _showEditEquipmentDialog(Equipment equipment) {
    print('_showEditEquipmentDialog called for equipment: ${equipment.id}');
    if (!mounted) return;
    
    print('Opening EditEquipmentDialog...');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditEquipmentDialog(
        equipment: equipment,
        user: widget.user,
        onEquipmentUpdated: () async {
          if (mounted) {
            await _loadSites();
            await _loadEquipment();
            // Показываем уведомление об успешном обновлении
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Оборудование успешно обновлено'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить оборудование'),
        content: Text('Вы уверены, что хотите удалить "${equipment.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEquipment(equipment);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEquipment(Equipment equipment) async {
    try {
      // Удаляем из Supabase
      await SupabaseService.deleteEquipment(equipment.id);
      
      // Удаляем из локального хранилища (для обратной совместимости)
      await StorageService.deleteEquipment(equipment.id);
      
      if (mounted) {
        setState(() {
          _equipment.removeWhere((e) => e.id == equipment.id);
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оборудование удалено')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  void _updateModelsList() {
    // Получаем уникальные модели из существующего оборудования
    final uniqueModels = _equipment.map((e) => e.model).toSet().toList();
    uniqueModels.sort();
    
    if (mounted) {
      setState(() {
        _models = ['Все модели', ...uniqueModels];
      });
    }
  }

  Future<void> _loadSites() async {
    try {
      List<Site> sites = [];
      
      // Для менеджера площадки загружаем только назначенные площадки
      if (widget.user.role == UserRole.siteManager && 
          widget.user.assignedSiteIds != null && 
          widget.user.assignedSiteIds!.isNotEmpty) {
        
        try {
          // Загружаем назначенные площадки из Supabase
          for (String siteId in widget.user.assignedSiteIds!) {
            try {
              final site = await SupabaseService.getSiteById(siteId);
              if (site != null) {
                sites.add(site);
              }
            } catch (e) {
              print('Ошибка загрузки площадки $siteId: $e');
            }
          }
        } catch (e) {
          print('Ошибка загрузки назначенных площадок: $e');
        }
      } else {
        // Для остальных ролей загружаем все площадки компании
        try {
          if (widget.user.companyId != null) {
            sites = await SupabaseService.getSites(widget.user.companyId!);
          }
        } catch (e) {
          print('Ошибка загрузки из Supabase: $e');
          // Если ошибка с Supabase, загружаем из локального хранилища
          sites = await StorageService.getSites(companyId: widget.user.companyId);
        }
      }
      
      if (mounted) {
        setState(() {
          _sites = sites;
          _locations = ['Все площадки', ...sites.map((site) => site.name)];
        });
      }
    } catch (e) {
      print('Ошибка загрузки площадок: $e');
    }
  }

  Future<void> _loadEquipment() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Используем новый метод для загрузки оборудования с учетом роли пользователя
      List<Equipment> filteredEquipment = await SupabaseService.getUserEquipment(widget.user);
      
      // Применяем дополнительные фильтры (только если они доступны для роли)
      if (_canUseFilters()) {
        filteredEquipment = _applyFilters(filteredEquipment);
      }
      
      if (mounted) {
        setState(() {
          _equipment = filteredEquipment;
          _isLoading = false;
        });
      }
      
      // Обновляем список моделей на основе существующего оборудования
      _updateModelsList();
    } catch (e) {
      print('Ошибка загрузки оборудования: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Проверяет, может ли пользователь использовать фильтры
  bool _canUseFilters() {
    // Ответственное лицо и администраторы могут использовать все фильтры
    if (widget.user.role == UserRole.companyResponsible || 
        widget.user.role == UserRole.administrator) {
      return true;
    }
    
    // Менеджер площадки может использовать фильтры только если у него назначено 2+ площадок
    if (widget.user.role == UserRole.siteManager) {
      return (widget.user.assignedSiteIds?.length ?? 0) >= 2;
    }
    
    return false;
  }

  /// Проверяет, может ли пользователь видеть фильтр площадок
  bool _canUseSiteFilter() {
    // Ответственное лицо и администраторы всегда видят фильтр площадок
    if (widget.user.role == UserRole.companyResponsible || 
        widget.user.role == UserRole.administrator) {
      return true;
    }
    
    // Менеджер площадки видит фильтр площадок только если у него назначено 2+ площадок
    if (widget.user.role == UserRole.siteManager) {
      return (widget.user.assignedSiteIds?.length ?? 0) >= 2;
    }
    
    return false;
  }

  /// Проверяет, может ли пользователь создавать/редактировать оборудование
  bool _canManageEquipment() {
    return widget.user.canManageEquipment;
  }

  /// Проверяет, может ли пользователь изменять статус оборудования
  bool _canChangeStatus() {
    return widget.user.role == UserRole.operatorPM || 
           widget.user.canManageEquipment;
  }

  /// Показывает диалог изменения статуса оборудования
  void _showStatusChangeDialog(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить статус: ${equipment.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EquipmentStatus.values.map((status) {
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(_getEquipmentStatusText(status)),
              selected: equipment.status == status,
              onTap: () {
                Navigator.pop(context);
                _updateEquipmentStatus(equipment, status);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  /// Обновляет статус оборудования
  Future<void> _updateEquipmentStatus(Equipment equipment, EquipmentStatus newStatus) async {
    try {
      // Обновляем в Supabase
      await SupabaseService.updateEquipmentStatus(equipment.id, newStatus.toString().split('.').last);
      
      // Обновляем локальное состояние
      setState(() {
        final index = _equipment.indexWhere((e) => e.id == equipment.id);
        if (index != -1) {
          _equipment[index] = Equipment(
            id: equipment.id,
            clientId: equipment.clientId,
            companyId: equipment.companyId,
            name: equipment.name,
            manufacturer: equipment.manufacturer,
            model: equipment.model,
            serialNumber: equipment.serialNumber,
            location: equipment.location,
            address: equipment.address,
            status: newStatus,
            createdAt: equipment.createdAt,
            updatedAt: DateTime.now(),
            siteId: equipment.siteId,
            modification: equipment.modification,
            description: equipment.description,
          );
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Статус изменен на: ${_getEquipmentStatusText(newStatus)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка изменения статуса: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Получает текстовое представление статуса оборудования
  String _getEquipmentStatusText(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return 'Активно';
      case EquipmentStatus.maintenance:
        return 'Требует обслуживания';
      case EquipmentStatus.broken:
        return 'Не работает';
      case EquipmentStatus.inactive:
        return 'На обслуживании';
    }
  }

  Color _getStatusColor(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return Colors.green;
      case EquipmentStatus.maintenance:
        return Colors.orange;
      case EquipmentStatus.broken:
        return Colors.red;
      case EquipmentStatus.inactive:
        return Colors.grey;
    }
  }

  List<Equipment> _applyFilters(List<Equipment> equipment) {
    List<Equipment> filtered = equipment;
    
    // Фильтр по площадке
    if (_selectedLocation != null && _selectedLocation != 'Все площадки') {
      // Находим выбранную площадку
      final selectedSite = _sites.firstWhere(
        (site) => site.name == _selectedLocation,
        orElse: () => Site(
          id: '',
          companyId: '',
          name: '',
          address: '',
          createdAt: DateTime.now(),
        ),
      );
      
      if (selectedSite.id.isNotEmpty) {
        // Фильтруем оборудование по площадке
        filtered = filtered.where((eq) => 
          eq.location.contains(_selectedLocation!) || 
          eq.address.contains(_selectedLocation!) ||
          (selectedSite.address.isNotEmpty && eq.address.contains(selectedSite.address))
        ).toList();
      } else {
        // Если площадка не найдена, показываем пустой список
        filtered = [];
      }
    }
    
    // Фильтр по модели
    if (_selectedModel != null && _selectedModel != 'Все модели') {
      filtered = filtered.where((eq) => eq.model == _selectedModel).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Фильтры (только для определенных ролей)
          if (_canUseFilters()) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Фильтры в ряд
                  Row(
                    children: [
                      // Блок площадки
                      if (_canUseSiteFilter())
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Площадка',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilterDropdown(
                                hint: 'Все площадки',
                                value: _selectedLocation,
                                items: _locations,
                                onChanged: (value) {
                                  setState(() => _selectedLocation = value);
                                  _loadEquipment();
                                },
                              ),
                            ],
                          ),
                        ),
                      
                      if (_canUseSiteFilter()) const SizedBox(width: 12),
                      
                      // Блок модели
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Модель', // На скриншоте оба "Площадка", но логично "Модель"
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilterDropdown(
                              hint: 'Все модели',
                              value: _selectedModel,
                              items: _models,
                              onChanged: (value) {
                                setState(() => _selectedModel = value);
                                _loadEquipment();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Кнопки добавления
                  if (widget.user.canManageSites) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: widget.onAddSite ?? _showAddLocationDialog,
                        icon: const Icon(Icons.add_location_alt_rounded, size: 20, color: Color(0xFF4285F4)),
                        label: const Text('Добавить площадку'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4285F4), width: 1.5),
                          foregroundColor: const Color(0xFF4285F4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (_canManageEquipment()) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: widget.onAddEquipment ?? _showAddEquipmentDialog,
                        icon: const Icon(Icons.add_rounded, size: 22),
                        label: const Text('Добавить технику'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          
          const SizedBox(height: 16),
          
          // Список оборудования
          _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _equipment.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: _equipment.map((equipment) => 
                        _buildModernEquipmentCard(equipment)
                      ).toList(),
                    ),
        ],
      ),
    );
  }

  void _editEquipment(Equipment equipment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditEquipmentDialog(
        equipment: equipment,
        user: widget.user,
        onEquipmentUpdated: () async {
          await _loadSites();
          await _loadEquipment();
        },
      ),
    );
  }

  void _showEquipmentDetails(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Содержимое с прокруткой
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Заголовок с изображением (адаптивный)
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(
                          minHeight: 140,
                          maxHeight: 300,
                        ),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          color: Colors.white, // Фон теперь белый
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: _buildEquipmentImage(equipment, fit: BoxFit.contain),
                        ),
                      ),
                      
                      // Информация
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Название
                            Text(
                              '${equipment.manufacturer} ${equipment.model}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Тип оборудования
                            if (equipment.type != null) ...[
                              _buildDetailRow(Icons.category_outlined, 'Тип', equipment.type!),
                              const SizedBox(height: 8),
                            ],
                            
                            // Дата реализации
                            if (equipment.purchaseDate != null) ...[
                              _buildDetailRow(Icons.calendar_today_outlined, 'Дата реализации', 
                                '${equipment.purchaseDate!.day}.${equipment.purchaseDate!.month}.${equipment.purchaseDate!.year}'),
                              const SizedBox(height: 8),
                            ],
                            
                            // Характеристики
                            _buildDetailRow(Icons.numbers, 'Серийный номер', equipment.serialNumber ?? 'Не указан'),
                            const SizedBox(height: 8),
                            _buildDetailRow(Icons.location_on, 'Площадка', equipment.address.isNotEmpty ? equipment.address : equipment.location),
                            const SizedBox(height: 8),
                            _buildDetailRow(Icons.info_outline, 'Статус', _getEquipmentStatusText(equipment.status)),
                            if (equipment.siteManagerContact != null && equipment.siteManagerContact!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(Icons.person_outline, 'Менеджер', equipment.siteManagerContact!),
                            ],
                            if (equipment.operatorContact != null && equipment.operatorContact!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(Icons.engineering_outlined, 'Оператор ПМ', equipment.operatorContact!),
                            ],
                            const SizedBox(height: 16),
                            
                            // Кнопки действий (адаптивные)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 280;
                                return Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          widget.onPartsClick?.call(equipment);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF3B82F6),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(double.infinity, 48),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.build_circle_outlined, size: 18),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Запчасти',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: isNarrow ? 13 : 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          widget.onServiceClick?.call(equipment.id);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red, width: 1.5),
                                          minimumSize: const Size(double.infinity, 48),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.build_outlined, size: 18),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Сервис',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: isNarrow ? 13 : 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Технические характеристики
                            EquipmentSpecificationsWidget(
                              manufacturer: equipment.manufacturer,
                              model: equipment.model,
                              customSpecs: equipment.specifications,
                            ),
                            
                            // График ТО
                            EquipmentMaintenanceWidget(
                              equipment: equipment,
                              onUpdated: () async {
                                Navigator.pop(context);
                                await _loadEquipment();
                                if (mounted) {
                                  _showEquipmentDetails(_equipment.firstWhere((e) => e.id == equipment.id));
                                }
                              }
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Кнопка редактирования
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _editEquipment(equipment);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF3B82F6),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Редактировать'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


  Widget _buildModernEquipmentCard(Equipment equipment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showEquipmentDetails(equipment),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Круглая иконка слева (аватар)
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildEquipmentImage(equipment),
                ),
                
                const SizedBox(width: 12),
                
                // Информация справа
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Производитель и модель
                      Text(
                        '${equipment.manufacturer} ${equipment.model}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 2),
                      
                      // Серийный номер
                      if (equipment.serialNumber != null && equipment.serialNumber!.isNotEmpty)
                        Text(
                          'S/N: ${equipment.serialNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 2),
                      
                      // Площадка
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              equipment.address.isNotEmpty ? equipment.address : equipment.location,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // Краткие характеристики
                      if (_shouldShowSpecsPreview(equipment)) ...[
                        const SizedBox(height: 4),
                        _buildSpecsPreview(equipment),
                      ],
                    ],
                  ),
                ),
                
                // Стрелка справа
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentImageHeader(Equipment equipment) {
    return Container(
      height: 200, // Увеличиваем высоту
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: Stack(
          children: [
            // Основное изображение
            Positioned.fill(
              child: _buildEquipmentImage(equipment),
            ),
            
            // Градиент для лучшего контраста текста
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            
            // Статус поверх изображения
            Positioned(
              top: 12,
              right: 12,
              child: _buildStatusChip(equipment.status, isOverlay: true),
            ),
            
            // Кнопка редактирования (для админов)
            if (widget.user.role == UserRole.administrator)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _editEquipment(equipment),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit,
                          color: Color(0xFF3B82F6),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Название поверх изображения
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: InkWell(
                onTap: () => widget.onViewDetails?.call(equipment.id) ?? _showEquipmentDetails(equipment),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${equipment.manufacturer} ${equipment.model}${equipment.modification != null ? ' (${equipment.modification})' : ''}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(EquipmentStatus status, {bool isOverlay = false}) {
    Color backgroundColor = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isOverlay ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Text(
        _getEquipmentStatusText(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEquipmentInfo(Equipment equipment) {
    return Column(
      children: [
        // Адрес площадки
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                equipment.address.isNotEmpty ? equipment.address : 'Площадка не указана',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(Equipment equipment) {
    return Column(
      children: [
        // Кнопка Запчасти
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton.icon(
            onPressed: () => widget.onPartsClick?.call(equipment),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text(
              'Запчасти',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Кнопка Сервис
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () => widget.onServiceClick?.call(equipment.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.build_outlined, size: 18),
            label: const Text(
              'Сервис',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentImage(Equipment equipment, {BoxFit fit = BoxFit.cover}) {
    // Получаем возможные пути к изображениям
    final possiblePaths = ImageService.getPossibleImagePaths(
      equipment.manufacturer, 
      equipment.model
    );
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: _buildImageWithFallback(possiblePaths, equipment, fit: fit),
      ),
    );
  }

  Widget _buildImageWithFallback(List<String> paths, Equipment equipment, {BoxFit fit = BoxFit.cover}) {
    // Пробуем загрузить первое изображение
    return Image.asset(
      paths.first,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Если первое изображение не загрузилось, пробуем остальные
        return _tryNextImage(paths, 1, equipment, fit: fit);
      },
    );
  }

  Widget _tryNextImage(List<String> paths, int index, Equipment equipment, {BoxFit fit = BoxFit.cover}) {
    if (index >= paths.length) {
      // Если все пути исчерпаны, показываем изображение по умолчанию
      return _buildDefaultImage();
    }

    return Image.asset(
      paths[index],
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Пробуем следующий путь
        return _tryNextImage(paths, index + 1, equipment);
      },
    );
  }

  bool _shouldShowSpecsPreview(Equipment equipment) {
    return equipment.specifications != null && equipment.specifications!.isNotEmpty;
  }

  Widget _buildSpecsPreview(Equipment equipment) {
    final specs = equipment.specifications;
    if (specs == null || specs.isEmpty) return const SizedBox.shrink();

    // Выбираем ключевые характеристики (порядок важен)
    final keys = ['productivity', 'cleaningWidth', 'warranty', 'batteryType'];
    List<Widget> chips = [];

    for (var key in keys) {
      if (specs[key] != null) {
        final spec = specs[key];
        final value = spec['value']?.toString() ?? '';
        final unit = spec['unit']?.toString() ?? '';
        
        if (value.isNotEmpty) {
          chips.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Text(
                '$value${unit.isNotEmpty ? ' $unit' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
            ),
          );
        }
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF4A90E2).withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.precision_manufacturing,
          color: Color(0xFF4A90E2),
          size: 48,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 30,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет оборудования',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить фильтры',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Кнопка добавления как на скриншоте
            if (widget.user.canManageEquipment)
              ElevatedButton.icon(
                onPressed: widget.onAddEquipment ?? _showAddEquipmentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить технику'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary 
              ? const Color(0xFF4A90E2) 
              : Colors.white,
          foregroundColor: isPrimary 
              ? Colors.white 
              : const Color(0xFF4A90E2),
          elevation: 0,
          side: isPrimary 
              ? null 
              : const BorderSide(color: Color(0xFF4A90E2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _showAddLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddSiteDialog(
        user: widget.user,
        onSiteAdded: (site) {
          // Добавляем новую площадку в список и перезагружаем данные
          _loadSites();
        },
      ),
    );
  }

  void _addNewLocation(String location) {
    setState(() {
      _locations.add(location);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Площадка успешно добавлена'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAddEquipmentDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController modelController = TextEditingController();
    final TextEditingController serialController = TextEditingController();
    String? selectedLocation = _locations.first;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить оборудование'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Название оборудования',
                    hintText: 'Например: Экскаватор №1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'Модель',
                    hintText: 'Например: Caterpillar 320D',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serialController,
                  decoration: const InputDecoration(
                    labelText: 'Серийный номер',
                    hintText: 'Например: CAT0001234',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedLocation,
                  decoration: const InputDecoration(
                    labelText: 'Площадка',
                    border: OutlineInputBorder(),
                  ),
                  items: _locations
                      .where((location) => location != 'Все площадки')
                      .map((location) => DropdownMenuItem(
                            value: location,
                            child: Text(location),
                          ))
                      .toList(),
                  onChanged: (value) => selectedLocation = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty &&
                  modelController.text.isNotEmpty &&
                  selectedLocation != null) {
                Navigator.pop(context);
                await _addNewEquipment(
                  titleController.text,
                  modelController.text,
                  serialController.text,
                  selectedLocation!,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewEquipment(String title, String model, String serial, String location) async {
    try {
      // Находим выбранную площадку
      final selectedSite = _sites.firstWhere(
        (site) => site.name == location,
        orElse: () => Site(
          id: '', 
          companyId: widget.user.companyId ?? '', // Используем ID компании пользователя или пустую строку
          companyInn: widget.user.companyInn ?? '',
          name: '',
          address: '',
          createdAt: DateTime.now(),
        ),
      );

      // Создаем новое оборудование
      final newEquipment = Equipment(
        id: const Uuid().v4(), // Генерируем настоящий UUID
        clientId: widget.user.companyId ?? '1',
        companyId: widget.user.companyId,
        companyInn: widget.user.companyInn,
        siteId: selectedSite.id.isNotEmpty ? selectedSite.id : null,
        name: title,
        manufacturer: 'Неизвестно', // Временное значение
        model: model,
        serialNumber: serial.isNotEmpty ? serial : null,
        location: location,
        address: selectedSite.address.isNotEmpty ? selectedSite.address : location,
        status: EquipmentStatus.active,
        createdAt: DateTime.now(),
      );

      // Сохраняем в Supabase
      await SupabaseService.createEquipment(newEquipment);
      
      // Сохраняем в локальное хранилище (для совместимости)
      await StorageService.saveEquipment(newEquipment);

      if (mounted) {
        setState(() {
          _equipment.add(newEquipment);
          // Добавляем модель в фильтры если её нет
          if (!_models.contains(model)) {
            _models.add(model);
          }
          // Добавляем локацию в фильтры если её нет
          if (!_locations.contains(location)) {
            _locations.add(location);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оборудование успешно добавлено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding equipment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при добавлении оборудования: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
