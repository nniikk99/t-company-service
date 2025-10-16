import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import '../models/equipment.dart';
import '../models/notification.dart';
import '../theme/app_theme.dart';
import '../widgets/tab_navigation.dart';
import 'equipment_list_screen.dart';
import 'requests_list_screen.dart';
import 'analytics_screen.dart';
import 'site_management_screen.dart';
import 'database_check_screen.dart';
import 'client_management_screen.dart';
import 'employee_management_screen.dart';
import 'engineer_management_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'engineer_statistics_screen.dart';
import '../widgets/add_site_dialog.dart';
import '../widgets/add_equipment_dialog.dart';

enum ViewType {
  equipment,
  equipmentDetails,
  requests,
  analytics,
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
  bool _serviceModalOpen = false;
  bool _partsModalOpen = false;
  bool _addEquipmentModalOpen = false;
  bool _editEquipmentModalOpen = false;
  bool _addSiteModalOpen = false;
  
  List<NavigationTab> get _navigationTabs {
    // Для инженеров показываем только заявки и статистику
    if (_currentUser.role == UserRole.engineer) {
      return [
        NavigationTab(id: 'requests', label: 'Заявки'),
        NavigationTab(id: 'analytics', label: 'Статистика'),
      ];
    }
    
    // Для остальных ролей - стандартная навигация
    return [
      NavigationTab(id: 'equipment', label: 'Оборудование'),
      NavigationTab(id: 'requests', label: 'Заявки'),
      NavigationTab(id: 'analytics', label: 'Анализ'),
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
  void _handleLogout() {
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_id');
      await prefs.setBool('is_logged_in', false);
      // флаг блокировки автологина через Telegram на один раз
      await prefs.setBool('skip_auto_login_once', true);
      try { await SupabaseService.signOut(); } catch (_) {}
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      }
    }();
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
    );
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

  void _handleSettingsClick() {
    // TODO: Открыть настройки
  }

  void _handleNotificationsClick() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(user: _currentUser),
      ),
    ).then((_) => _loadUnreadNotifications()); // Обновляем счетчик после возврата
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
    setState(() {
      _selectedEquipmentId = equipmentId;
      _serviceModalOpen = true;
    });
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
      endDrawer: _buildProfileDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        leading: widget.adminUser != null
            ? IconButton(
                onPressed: () {
                  // Возвращаемся в меню управления клиентами
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClientManagementScreen(adminUser: widget.adminUser!),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                ),
                tooltip: 'Назад к управлению клиентами',
              )
            : null,
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Определяем размер экрана
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 600;
            
            if (isMobile) {
              // Мобильная версия - только логотип и меню
              return Row(
                children: [
                  // Логотип T-Co
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'T-Co',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Заголовок по центру
                  const Text(
                    'Сервисная служба',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ],
              );
            } else {
              // Десктопная версия - полная информация
              return Row(
                children: [
                  // Логотип T-Co
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'T-Co',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Заголовок по центру
                  const Text(
                    'Сервисная служба',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Профиль пользователя
                  GestureDetector(
                    onTap: _showProfileMenu,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Аватар с инициалами
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Text(
                              _getUserInitials(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Имя и роль
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_currentUser.firstName} ${_currentUser.lastName}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRoleColor(),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _currentUser.roleDisplayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(12), // container mx-auto px-3 py-3
        child: Column(
          children: [
            // Navigation Tabs - показываем только если не в режиме просмотра деталей
            if (_currentView != ViewType.equipmentDetails) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isMobile = screenWidth < 600;
                  
                  return Container(
                    margin: EdgeInsets.only(
                      bottom: 12,
                      left: isMobile ? 0 : 0,
                      right: isMobile ? 0 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isMobile ? 3 : 4),
                    child: Row(
                      children: _navigationTabs.map((tab) {
                        final isActive = _getActiveTabId() == tab.id;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _setCurrentView(tab.id),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 10 : 8,
                                horizontal: isMobile ? 8 : 12,
                              ),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? const Color(0xFF4A90E2) // telegram-blue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  tab.label,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: isActive 
                                        ? Colors.white 
                                        : Colors.black87, // telegram-text
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
            
            // Main Content
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
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
      case ViewType.analytics:
        return 'analytics';
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
        case 'analytics':
          _currentView = ViewType.analytics;
          break;
      }
    });
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case ViewType.equipment:
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
        // Для инженеров показываем специальную статистику
        if (_currentUser.role == UserRole.engineer) {
          return EngineerStatisticsScreen(engineerId: _currentUser.id);
        }
        return AnalyticsScreen(user: _currentUser);
    }
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

  Color _getRoleColor() {
    switch (_currentUser.role) {
      case UserRole.admin:
      case UserRole.superAdmin:
      case UserRole.administrator:
        return Colors.red;
      case UserRole.clientManager:
        return Colors.purple;
      case UserRole.clientResponsible:
      case UserRole.companyResponsible:
      case UserRole.supplier:
        return Colors.orange;
      case UserRole.contactPerson:
      case UserRole.siteManager:
      case UserRole.operatorPM:
      case UserRole.engineer:
        return Colors.green;
      case UserRole.pendingApproval:
        return Colors.grey;
    }
  }

  void _showProfileMenu() {
    Scaffold.of(context).openEndDrawer();
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      width: 320,
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Заголовок
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF4A90E2),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    // Аватар
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Center(
                        child: Text(
                          _getUserInitials(),
                          style: const TextStyle(
                            color: Color(0xFF4A90E2),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Имя пользователя
                    Text(
                      _currentUser.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Роль
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currentUser.roleDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Меню действий
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.person_outline,
                      title: 'Мой профиль',
                      onTap: () {
                        Navigator.pop(context);
                        _handleProfileClick();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.notifications_outlined,
                      title: 'Уведомления',
                      badge: _unreadNotifications > 0 ? _unreadNotifications.toString() : null,
                      onTap: () {
                        Navigator.pop(context);
                        _handleNotificationsClick();
                      },
                    ),
                    if (_currentUser.canManageClients) 
                      _buildDrawerItem(
                        icon: Icons.location_on_outlined,
                        title: 'Управление площадками',
                        onTap: () {
                          Navigator.pop(context);
                          _handleSiteManagement();
                        },
                      ),
                    if (_currentUser.canManageClients) 
                      _buildDrawerItem(
                        icon: Icons.apartment,
                        title: 'Управление клиентами',
                        onTap: () {
                          Navigator.pop(context);
                          _handleClientManagement();
                        },
                      ),
                    if (_currentUser.canManageClients) 
                      _buildDrawerItem(
                        icon: Icons.engineering,
                        title: 'Управление инженерами',
                        onTap: () {
                          Navigator.pop(context);
                          _handleEngineerManagement();
                        },
                      ),
                    // Сотрудники - только для ответственного лица
                    if (_currentUser.role == UserRole.companyResponsible)
                      _buildDrawerItem(
                        icon: Icons.people_outline,
                        title: 'Сотрудники',
                        onTap: () {
                          Navigator.pop(context);
                          _handleEmployeeManagement();
                        },
                      ),
                    if (_currentUser.canManageClients)
                      _buildDrawerItem(
                        icon: Icons.telegram,
                        title: 'Тест Telegram бота',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/telegram-bot-test');
                        },
                      ),
                    _buildDrawerItem(
                      icon: Icons.settings_outlined,
                      title: 'Настройки',
                      onTap: () {
                        Navigator.pop(context);
                        _handleSettingsClick();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.help_outline,
                      title: 'Помощь',
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Открыть помощь
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildDrawerItem(
                      icon: Icons.logout,
                      title: 'Выйти',
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                    ),
                  ],
                ),
              ),
              
              // Нижний блок
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'T-Co Service',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Версия 1.0.0',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? badge,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive ? Colors.red : Colors.grey[700],
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavigationTab {
  final String id;
  final String label;
  
  NavigationTab({required this.id, required this.label});
}