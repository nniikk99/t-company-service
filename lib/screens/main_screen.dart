import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
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
        NavigationTab(id: 'equipment', label: 'Оборудование +', icon: Icons.precision_manufacturing),
        NavigationTab(id: 'requests', label: 'Заказы/Заявки', icon: Icons.assignment_outlined),
        NavigationTab(id: 'analytics', label: 'Аналитика парка', icon: Icons.dashboard_outlined),
        NavigationTab(id: 'profile', label: 'Профиль', icon: Icons.person),
      ];
    }
    
    // Для остальных ролей - стандартная навигация
    return [
      NavigationTab(id: 'equipment', label: 'Оборудование', icon: Icons.build),
      NavigationTab(id: 'requests', label: 'Заявки', icon: Icons.list),
      NavigationTab(id: 'cart', label: 'Корзина', icon: Icons.shopping_cart),
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
      final notifications = await StorageService.getNotifications(userId: _currentUser.id);
      final unread = notifications.where((n) => !n.isRead).length;
      
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

  void _handlePartsClick(String equipmentId) {
    setState(() {
      _selectedEquipmentId = equipmentId;
      _partsModalOpen = true;
    });
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        leading: widget.adminUser != null
            ? IconButton(
                onPressed: () {
                  // Возвращаемся в меню управления клиентами
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                ),
                tooltip: 'Вернуться к управлению',
              )
            : null,
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Определяем размер экрана
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 600;
            
            if (isMobile) {
              // Мобильная версия - только заголовок
              return const Row(
                children: [
                  Spacer(),
                  // Заголовок по центру
                  Text(
                    'Сервисная служба',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                ],
              );
            } else {
              // Десктопная версия - полная информация
              return const Row(
                children: [
                  Spacer(),
                  // Заголовок по центру
                  Text(
                    'Сервисная служба',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                ],
              );
            }
          },
        ),
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: _buildMainContent(),
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
                                Icon(
                                  tab.icon,
                                  color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                  size: 26, // Increased from 24
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tab.label,
                                  style: TextStyle(
                                    fontSize: 11, // Increased from 10
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                                    color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                    letterSpacing: 0.2,
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
          return EngineerStatisticsScreen(engineerId: _currentUser.id);
        }
        return AnalyticsScreen(user: _currentUser);
      case ViewType.cart:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFF94A3B8)),
              SizedBox(height: 16),
              Text(
                'Корзина пуста',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Здесь будут отображаться заказанные детали',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        );
      case ViewType.profile:
        return _buildProfileTabContent();
    }
  }

  Widget _buildProfileTabContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Header section
          Center(
            child: Column(
              children: [
                // Avatar with blue circle and inner border
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2563EB), width: 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFE0F2FE)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getUserInitials(),
                      style: const TextStyle(
                        fontFamily: 'Liberation Sans',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Full Name
                Text(
                  _currentUser.fullName,
                  style: const TextStyle(
                    fontFamily: 'Liberation Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                // Phone Number
                Text(
                  _currentUser.phone.isNotEmpty ? _currentUser.phone : '+7 (XXX) XXX-XX-XX',
                  style: const TextStyle(
                    fontFamily: 'Liberation Sans',
                    fontSize: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentUser.roleDisplayName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Liberation Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Group 1: Profile
          _buildProfileSectionCard([
            _buildProfileMenuItem(
              icon: Icons.person,
              title: 'Личные данные',
              onTap: _handleProfileClick,
            ),
            _buildProfileMenuItem(
              icon: Icons.apartment,
              title: 'Мои организации',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyOrganizationsScreen(user: _currentUser)),
                );
              },
              showDivider: false,
            ),
          ]),
          const SizedBox(height: 16),

          // Group 2: Admin Panel (if any)
          ..._buildAdminPanel(),

          // Group 3: System
          _buildProfileSectionCard([
            _buildProfileMenuItem(
              icon: Icons.notifications,
              title: 'Настройки уведомлений',
              badge: _unreadNotifications > 0 ? _unreadNotifications.toString() : null,
              onTap: _handleNotificationsClick,
            ),
            _buildProfileMenuItem(
              icon: Icons.headset_mic,
              title: 'Техподдержка',
              onTap: () {},
            ),
            _buildProfileMenuItem(
              icon: Icons.info,
              title: 'О приложении',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'T-Co Service',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.settings, size: 48, color: Color(0xFF2563EB)),
                );
              },
              showDivider: false,
            ),
          ]),

          const SizedBox(height: 32),
          
          // Logout
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
              label: const Text(
                'Выйти',
                style: TextStyle(
                  fontFamily: 'Liberation Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.5),
                backgroundColor: const Color(0xFFFFFBFA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'T-Co Service v1.0.0',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  List<Widget> _buildAdminPanel() {
    List<Widget> items = [];
    
    if (_currentUser.role == UserRole.admin || _currentUser.role == UserRole.superAdmin || _currentUser.role == UserRole.administrator) {
      items.add(_buildProfileMenuItem(
        icon: Icons.admin_panel_settings_rounded,
        title: 'Инструменты БД',
        onTap: () => Navigator.pushNamed(context, '/database-check', arguments: _currentUser),
      ));
    }
    
    if (_currentUser.canManageSites) {
      items.add(_buildProfileMenuItem(
        icon: Icons.location_on_rounded,
        title: 'Управление площадками',
        onTap: _handleSiteManagement,
      ));
    }
    
    if (_currentUser.canManageClients) {
      items.add(_buildProfileMenuItem(
        icon: Icons.apartment_rounded,
        title: 'Управление пользователями',
        onTap: _handleClientManagement,
      ));
      items.add(_buildProfileMenuItem(
        icon: Icons.engineering_rounded,
        title: 'Управление инженерами',
        onTap: _handleEngineerManagement,
      ));
    }
    
    if (_currentUser.role == UserRole.superAdmin || _currentUser.role == UserRole.administrator) {
      items.add(_buildProfileMenuItem(
        icon: Icons.precision_manufacturing_rounded,
        title: 'Оборудование (Админ)',
        onTap: _handleAdminEquipment,
      ));
    }
    
    if (_currentUser.role == UserRole.companyResponsible) {
      items.add(_buildProfileMenuItem(
        icon: Icons.people_rounded,
        title: 'Сотрудники',
        onTap: _handleEmployeeManagement,
      ));
    }
      
    if (_currentUser.role == UserRole.supplier) {
      items.add(_buildProfileMenuItem(
        icon: Icons.add_business_rounded,
        title: 'Оборудование +',
        onTap: _handleSupplierEquipment,
      ));
      items.add(_buildProfileMenuItem(
        icon: Icons.people_alt_rounded,
        title: 'Клиенты',
        onTap: _handleSupplierClients,
      ));
      items.add(_buildProfileMenuItem(
        icon: Icons.handshake_rounded,
        title: 'Партнеры',
        onTap: _handleSupplierPartners,
      ));
      items.add(_buildProfileMenuItem(
        icon: Icons.branding_watermark_rounded,
        title: 'Товарные знаки',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SupplierBrandsScreen(supplier: _currentUser)),
          );
        },
      ));
      items.add(_buildProfileMenuItem(
        icon: Icons.build_circle_rounded,
        title: 'Запчасти',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SupplierSparePartsScreen(supplier: _currentUser)),
          );
        },
      ));
    }

    if (items.isEmpty) return [];

    // Set showDivider: false for the last item
    if (items.isNotEmpty) {
      // This is a bit hacky but works since _buildProfileMenuItem returns Column
      // The original instruction had a complex hack here.
      // The new approach is to use _buildAdminItemsList which handles dividers.
    }
    
    // Better way: Re-implement _buildAdminPanel to take showDivider flag
    return [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 8, top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'ПАНЕЛЬ УПРАВЛЕНИЯ',
            style: TextStyle(
              fontFamily: 'Liberation Sans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      _buildProfileSectionCard(_buildAdminItemsList()),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildAdminItemsList() {
    List<Map<String, dynamic>> itemsData = [];
    
    void add(IconData icon, String title, VoidCallback onTap) {
      itemsData.add({'icon': icon, 'title': title, 'onTap': onTap});
    }

    if (_currentUser.role == UserRole.admin || _currentUser.role == UserRole.superAdmin || _currentUser.role == UserRole.administrator) {
      add(Icons.dns, 'Инструменты БД', () => Navigator.pushNamed(context, '/database-check', arguments: _currentUser));
    }
    if (_currentUser.canManageSites) {
      add(Icons.map, 'Управление площадками', _handleSiteManagement);
    }
    if (_currentUser.canManageClients) {
      add(Icons.people, 'Управление пользователями', _handleClientManagement);
      add(Icons.work, 'Управление инженерами', _handleEngineerManagement);
    }
    if (_currentUser.role == UserRole.superAdmin || _currentUser.role == UserRole.administrator) {
      add(Icons.settings, 'Управление оборудованием', _handleAdminEquipment);
    }
    if (_currentUser.role == UserRole.companyResponsible) {
      add(Icons.badge, 'Сотрудники', _handleEmployeeManagement);
    }
    if (_currentUser.role == UserRole.supplier) {
      add(Icons.add_box, 'Оборудование +', _handleSupplierEquipment);
      add(Icons.domain, 'Клиенты', _handleSupplierClients);
      add(Icons.handshake, 'Партнеры', _handleSupplierPartners);
    }

    return List.generate(itemsData.length, (index) {
      final data = itemsData[index];
      return _buildProfileMenuItem(
        icon: data['icon'],
        title: data['title'],
        onTap: data['onTap'],
        showDivider: index < itemsData.length - 1,
      );
    });
  }

  Widget _buildProfileSectionCard(List<Widget> items) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: items,
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    String? badge,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon background
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Liberation Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                // Badge if exists
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                // Arrow
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 24),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 72, endIndent: 16, color: Color(0xFFF1F5F9)),
      ],
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
  final IconData icon;
  
  NavigationTab({required this.id, required this.label, required this.icon});
}