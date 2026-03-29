import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import '../models/equipment.dart';
import 'equipment_list_screen.dart';
import 'requests_list_screen.dart';
import 'analytics_screen.dart';
import 'site_management_screen.dart';
import 'client_management_screen.dart';
import 'employee_management_screen.dart';
import 'engineer_management_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'engineer_statistics_screen.dart';
import 'supplier_equipment_screen.dart';
import 'supplier_clients_screen.dart';
import 'supplier_partners_screen.dart';
import 'supplier_spare_parts_screen.dart';
import 'supplier_brands_screen.dart';
import 'supplier_fleet_screen.dart';
import 'my_organizations_screen.dart';
import '../widgets/add_site_dialog.dart';
import '../widgets/add_equipment_dialog.dart';
import '../widgets/service_request_dialog.dart';
import 'model_selection_screen.dart';
import 'client_spare_parts_screen.dart';
import 'market_screen.dart';

enum ViewType {
  equipment,
  equipmentDetails,
  requests,
  cart,
  analytics,
  profile,
}

class MainScreen extends StatefulWidget {
  final User user;
  final ViewType? initialView;
  final User? adminUser; // Для возврата в админ-панель

  const MainScreen({
    super.key, 
    required this.user,
    this.initialView,
    this.adminUser,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late ViewType _currentView;
  late User _currentUser; // Добавляем состояние для текущего пользователя
  String? _selectedEquipmentId;
  int _unreadNotifications = 0; // Счетчик непрочитанных уведомлений
  
  // Модальные окна
  final bool _serviceModalOpen = false;
  bool _partsModalOpen = false;
  final bool _addEquipmentModalOpen = false;
  bool _editEquipmentModalOpen = false;
  final bool _addSiteModalOpen = false;

  // Предотвращение удаления иконок при сборке на Web (Tree-shaking)
  // Flutter Web агрессивно удаляет все иконки, кроме тех, что вызываются напрямую через const Icon(...)
  final List<Icon> _dummyIconsForWeb = const [
    Icon(Icons.list),
    Icon(Icons.bar_chart),
    Icon(Icons.build),
    Icon(Icons.shopping_cart),
    Icon(Icons.person),
    Icon(Icons.apartment),
    Icon(Icons.dns),
    Icon(Icons.map),
    Icon(Icons.people),
    Icon(Icons.work),
    Icon(Icons.settings),
    Icon(Icons.badge),
    Icon(Icons.add_box),
    Icon(Icons.domain),
    Icon(Icons.handshake),
    Icon(Icons.notifications),
    Icon(Icons.headset_mic),
    Icon(Icons.info),
    Icon(Icons.logout),
  ];
  
  List<NavigationTab> get _navigationTabs {
    // Для инженеров показываем только заявки и статистику
    if (_currentUser.role == UserRole.engineer) {
      return [
        NavigationTab(id: 'requests', label: 'Заявки', icon: Icons.list),
        NavigationTab(id: 'analytics', label: 'Статистика', icon: Icons.bar_chart),
        NavigationTab(id: 'profile', label: 'Профиль', icon: Icons.person),
      ];
    }
    
    // Для поставщиков
    if (_currentUser.role == UserRole.supplier) {
      return [
        NavigationTab(id: 'equipment', label: 'Товары', customIconPath: 'assets/icons/cleaning_machine.png'),
        NavigationTab(id: 'requests', label: 'Заказы', icon: Icons.assignment_outlined),
        NavigationTab(id: 'analytics', label: 'Аналитика', icon: Icons.dashboard_outlined),
        NavigationTab(id: 'profile', label: 'Профиль', icon: Icons.person),
      ];
    }
    
    // Для остальных ролей - стандартная навигация
    return [
      NavigationTab(id: 'equipment', label: 'Техника', customIconPath: 'assets/icons/cleaning_machine.png'),
      NavigationTab(id: 'requests', label: 'Заявки', icon: Icons.list),
      NavigationTab(id: 'cart', label: 'Маркет', icon: Icons.shopping_cart),
      NavigationTab(id: 'analytics', label: 'Анализ', icon: Icons.bar_chart),
      NavigationTab(id: 'profile', label: 'Профиль', icon: Icons.person),
    ];
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user; // Инициализируем текущего пользователя
    
    // Для инженеров по умолчанию показываем заявки
    if (_currentUser.role == UserRole.engineer) {
      _currentView = widget.initialView ?? ViewType.requests;
    } else {
      _currentView = widget.initialView ?? ViewType.equipment;
    }
    
    _loadUnreadNotifications(); // Загружаем количество непрочитанных уведомлений
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем счетчик уведомлений при каждом возврате на экран
    _loadUnreadNotifications();
  }

  // Обработчики событий (как в React коде)
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.clearAll();
      try { await SupabaseService.signOut(); } catch (_) {}
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _handleProfileClick() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          user: _currentUser,
          adminUser: widget.adminUser,
          onUserUpdated: (updatedUser) {
            setState(() {
              _currentUser = updatedUser;
            });
          },
        ),
      ),
    ).then((_) => _loadUnreadNotifications());
  }

  void _handleSiteManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SiteManagementScreen(user: _currentUser),
      ),
    );
  }

  void _handleClientManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientManagementScreen(adminUser: _currentUser),
      ),
    );
  }

  void _handleEngineerManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EngineerManagementScreen(adminUser: _currentUser),
      ),
    );
  }

  void _handleEmployeeManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeManagementScreen(responsibleUser: _currentUser),
      ),
    );
  }

  void _handleSupplierEquipment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierEquipmentScreen(supplier: _currentUser),
      ),
    );
  }

  void _handleAdminEquipment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierEquipmentScreen(supplier: _currentUser, isAdminMode: true),
      ),
    );
  }

  void _handleSupplierClients() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierClientsScreen(supplier: _currentUser),
      ),
    );
  }

  void _handleSupplierPartners() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierPartnersScreen(supplier: _currentUser),
      ),
    );
  }

  void _handleSettingsClick() {
    // TODO: Открыть настройки
  }

  void _handleNotificationsClick() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(user: _currentUser),
      ),
    ).then((_) => _loadUnreadNotifications());
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final notificationsData = await SupabaseService.getNotifications(_currentUser.id);
      final unread = notificationsData.where((n) => n['is_read'] == false || n['is_read'] == null).length;
      
      if (mounted) {
        setState(() {
          _unreadNotifications = unread;
        });
      }
    } catch (e) {
      print('⚠️ Ошибка загрузки уведомлений: $e');
    }
  }

  void _handleAddEquipment() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEquipmentDialog(
        user: _currentUser,
        onEquipmentAdded: (equipment) {
          // Обновляем экран после добавления оборудования
          setState(() {});
        },
      ),
    );
  }

  void _handleAddSite() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddSiteDialog(
        user: _currentUser,
        onSiteAdded: (site) {
          // Обновляем экран после добавления площадки
          setState(() {});
        },
      ),
    );
  }

  void _handleServiceClick(String equipmentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ServiceRequestDialog(
        equipmentId: equipmentId,
        user: _currentUser,
        onRequestCreated: () {
          // После создания заявки переходим на вкладку заявок
          setState(() {
            _currentView = ViewType.requests;
          });
        },
      ),
    );
  }

  void _handlePartsClick(Equipment equipment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSparePartsScreen(
          user: _currentUser,
          modelName: '${equipment.manufacturer} ${equipment.model}',
        ),
      ),
    );
  }

  void _handleViewEquipmentDetails(String equipmentId) {
    setState(() {
      _selectedEquipmentId = equipmentId;
      _currentView = ViewType.equipmentDetails;
    });
  }

  void _handleBackToEquipmentList() {
    setState(() {
      _currentView = ViewType.equipment;
      _selectedEquipmentId = null;
    });
  }

  void _handleEditEquipment(String equipmentId) {
    setState(() {
      _selectedEquipmentId = equipmentId;
      _editEquipmentModalOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // telegram-background
      appBar: widget.adminUser != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 60,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF2563EB), size: 20),
                    tooltip: 'Вернуться',
                  ),
                ),
              ),
            )
          : null,
      extendBodyBehindAppBar: widget.adminUser != null,
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: _buildMainContent(),
        ),
      ),
      bottomNavigationBar: _currentView != ViewType.equipmentDetails 
        ? Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _navigationTabs.map((tab) {
                    final isActive = _getActiveTabId() == tab.id;
                    return Expanded(
                      child: Tooltip(
                        message: tab.label,
                        child: InkWell(
                          onTap: () => _setCurrentView(tab.id),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                tab.customIconPath != null
                                    ? ImageIcon(
                                        AssetImage(tab.customIconPath!),
                                        color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                        size: 22,
                                      )
                                    : Icon(
                                        tab.icon,
                                        color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                        size: 22,
                                      ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tab.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                      color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          )
        : null,
    );
  }

  String _getActiveTabId() {
    switch (_currentView) {
      case ViewType.equipment:
      case ViewType.equipmentDetails:
        // Инженеры не видят вкладку оборудования
        if (_currentUser.role == UserRole.engineer) {
          return 'requests'; // По умолчанию показываем заявки
        }
        return 'equipment';
      case ViewType.requests:
        return 'requests';
      case ViewType.cart:
        return 'cart';
      case ViewType.analytics:
        return 'analytics';
      case ViewType.profile:
        return 'profile';
    }
  }

  void _setCurrentView(String tabId) {
    setState(() {
      switch (tabId) {
        case 'equipment':
          // Инженеры не могут переходить к оборудованию
          if (_currentUser.role != UserRole.engineer) {
            _currentView = ViewType.equipment;
          }
          break;
        case 'requests':
          _currentView = ViewType.requests;
          break;
        case 'cart':
          _currentView = ViewType.cart;
          break;
        case 'analytics':
          _currentView = ViewType.analytics;
          break;
        case 'profile':
          _currentView = ViewType.profile;
          break;
      }
    });
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case ViewType.equipment:
        if (_currentUser.role == UserRole.supplier) {
          return SupplierEquipmentScreen(supplier: _currentUser);
        }
        return EquipmentListScreen(
          key: ValueKey('equipment_${DateTime.now().millisecondsSinceEpoch}'),
          user: _currentUser,
          onAddEquipment: _handleAddEquipment,
          onAddSite: _handleAddSite,
          onServiceClick: _handleServiceClick,
          onPartsClick: _handlePartsClick,
          onViewDetails: _handleViewEquipmentDetails,
        );
      
      case ViewType.equipmentDetails:
        // Убираем заглушку - просто возвращаемся к списку оборудования
        return EquipmentListScreen(
          key: ValueKey('equipment_simple_${DateTime.now().millisecondsSinceEpoch}'),
          user: _currentUser,
          onAddEquipment: _handleAddEquipment,
          onAddSite: _handleAddSite,
        );
        
      case ViewType.requests:
        return RequestsListScreen(user: _currentUser);
        
      case ViewType.analytics:
        if (_currentUser.role == UserRole.supplier) {
          return SupplierFleetScreen(supplier: _currentUser);
        }
        // Для инженеров показываем специальную статистику
        if (_currentUser.role == UserRole.engineer) {
          return EngineerStatisticsScreen(
            engineerId: _currentUser.id,
            currentUser: _currentUser,
          );
        }
        return AnalyticsScreen(user: _currentUser);
      case ViewType.cart:
        return MarketScreen(user: _currentUser);
      case ViewType.profile:
        return _buildProfileTabContent();
    }
  }

  Widget _buildProfileTabContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Основная карточка профиля
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEFF6FF), // Light blue background
                      ),
                      child: const Center(
                        child: Icon(Icons.person_outline, size: 32, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _currentUser.roleDisplayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),
                Row(
                  children: [
                    const Icon(Icons.business, color: Color(0xFF94A3B8), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentUser.companyName ?? 'Организация не указана',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentUser.companyAddress ?? 'Адрес не указан',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Статистика
          Row(
            children: [
              Expanded(child: _buildStatCard('4', 'Оборудование')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('5', 'Заявки')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('2', 'Заказы')),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Опции меню
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.notifications_none,
                  title: 'Уведомления',
                  badge: _unreadNotifications > 0 ? '$_unreadNotifications' : null,
                  onTap: _handleNotificationsClick,
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 24, endIndent: 24),
                
                // Редактирование профиля
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'Личные данные',
                  onTap: _handleProfileClick,
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 24, endIndent: 24),
                
                // Мои организации (для Клиентов, Админов и Поставщиков)
                if (_currentUser.role != UserRole.engineer) ...[
                  _buildMenuItem(
                    icon: Icons.apartment_outlined,
                    title: 'Мои организации',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyOrganizationsScreen(user: _currentUser)),
                      );
                    },
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 24, endIndent: 24),
                ],

                // "Роли и доступ" (Инструменты администратора) / Привязанный функционал из старого меню
                ..._buildAdminPanelMenu(),
                
                _buildMenuItem(
                  icon: Icons.help_outline,
                  title: 'Помощь',
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'T-Co Service',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.settings, size: 48, color: Color(0xFF2563EB)),
                    );
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 24, endIndent: 24),
                
                // Выход
                _buildMenuItem(
                  icon: Icons.logout,
                  title: 'Выйти',
                  textColor: const Color(0xFFEF4444),
                  iconColor: const Color(0xFFEF4444),
                  iconBgColor: const Color(0xFFFEF2F2),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatCard(String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdminPanelMenu() {
    List<Widget> items = [];
    
    void add(IconData icon, String title, VoidCallback onTap) {
      items.add(_buildMenuItem(icon: icon, title: title, onTap: onTap));
      items.add(const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 24, endIndent: 24));
    }

    if (_currentUser.role == UserRole.administrator) {
      add(Icons.security, 'Роли и доступ БД', () => Navigator.pushNamed(context, '/database-check', arguments: _currentUser));
    }
    if (_currentUser.canManageSites) {
      add(Icons.map_outlined, 'Управление площадками', _handleSiteManagement);
    }
    if (_currentUser.canManageClients) {
      add(Icons.people_outline, 'Управление пользователями', _handleClientManagement);
      add(Icons.engineering_outlined, 'Управление инженерами', _handleEngineerManagement);
    }
    if (_currentUser.role == UserRole.administrator) {
      add(Icons.settings_outlined, 'Оборудование (Админ)', _handleAdminEquipment);
    }
    if (_currentUser.role == UserRole.companyResponsible) {
      add(Icons.badge_outlined, 'Сотрудники', _handleEmployeeManagement);
    }
    if (_currentUser.role == UserRole.supplier) {
      add(Icons.add_box_outlined, 'Оборудование +', _handleSupplierEquipment);
      add(Icons.domain, 'Клиенты', _handleSupplierClients);
      add(Icons.handshake_outlined, 'Партнеры', _handleSupplierPartners);
      add(Icons.branding_watermark_outlined, 'Товарные знаки', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SupplierBrandsScreen(supplier: _currentUser)),
        );
      });
      add(Icons.build_circle_outlined, 'Запчасти', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SupplierSparePartsScreen(supplier: _currentUser)),
        );
      });
    }

    return items;
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? badge,
    Color textColor = const Color(0xFF0F172A),
    Color iconColor = const Color(0xFF0F172A),
    Color iconBgColor = const Color(0xFFF8FAFC),
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 12),
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 24),
          ],
        ),
      ),
    );
  }

  String _getUserInitials() {
    final firstInitial = _currentUser.firstName.isNotEmpty 
        ? _currentUser.firstName[0].toUpperCase() 
        : '';
    final lastInitial = _currentUser.lastName.isNotEmpty 
        ? _currentUser.lastName[0].toUpperCase() 
        : '';
    return '$firstInitial$lastInitial';
  }
}

class NavigationTab {
  final String id;
  final String label;
  final IconData? icon;
  final String? customIconPath;
  
  NavigationTab({
    required this.id, 
    required this.label, 
    this.icon,
    this.customIconPath,
  }) : assert(icon != null || customIconPath != null);
}