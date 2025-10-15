import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/notification.dart';
import '../services/app_router.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/admin_dashboard.dart';
import '../widgets/responsible_dashboard.dart';
import '../widgets/contact_dashboard.dart';
import 'notifications_screen.dart';
import 'database_check_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User? user;

  const DashboardScreen({super.key, this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late List<NavigationItem> _navigationItems;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _setupNavigation();
    _loadUnreadNotifications();
  }

  Future<void> _loadUnreadNotifications() async {
    if (widget.user == null) return;
    
    try {
      final notifications = await StorageService.getNotifications(userId: widget.user!.id);
      final unread = notifications.where((n) => !n.isRead).length;
      
      if (mounted) {
        setState(() {
          _unreadNotifications = unread;
        });
      }
    } catch (e) {
      // Игнорируем ошибку
    }
  }

  void _setupNavigation() {
    final user = widget.user;
    if (user == null) {
      _navigationItems = [];
      return;
    }

    switch (user.role) {
      case UserRole.admin:
      case UserRole.superAdmin:
      case UserRole.administrator:
        _navigationItems = [
          NavigationItem('Главная', Icons.dashboard, _buildAdminDashboard),
          NavigationItem('Управление клиентами', Icons.apartment, _buildClientsManagement),
          NavigationItem('Оборудование', Icons.build, _buildEquipmentPlaceholder),
          NavigationItem('Заявки', Icons.assignment, _buildRequestsPlaceholder),
          NavigationItem('Админ', Icons.admin_panel_settings, _buildAdminPlaceholder),
        ];
        break;
      case UserRole.clientResponsible:
      case UserRole.companyResponsible:
      case UserRole.supplier:
        _navigationItems = [
          NavigationItem('Главная', Icons.dashboard, _buildResponsibleDashboard),
          NavigationItem('Оборудование', Icons.build, _buildEquipmentPlaceholder),
          NavigationItem('Заявки', Icons.assignment, _buildRequestsPlaceholder),
          NavigationItem('Профиль', Icons.person, _buildProfile),
        ];
        break;
      case UserRole.clientManager:
      case UserRole.contactPerson:
      case UserRole.siteManager:
      case UserRole.operatorPM:
      case UserRole.engineer:
        _navigationItems = [
          NavigationItem('Главная', Icons.dashboard, _buildContactDashboard),
          NavigationItem('Оборудование', Icons.build, _buildEquipmentPlaceholder),
          NavigationItem('Заявки', Icons.assignment, _buildRequestsPlaceholder),
          NavigationItem('Профиль', Icons.person, _buildProfile),
        ];
        break;
      case UserRole.pendingApproval:
        _navigationItems = [
          NavigationItem('Ожидание', Icons.hourglass_empty, _buildProfile),
        ];
        break;
    }
  }

  void _navigateToEquipment() {
    Navigator.pushNamed(context, AppRouter.equipment, arguments: widget.user);
  }

  void _navigateToRequests() {
    Navigator.pushNamed(context, AppRouter.requests, arguments: widget.user);
  }

  void _navigateToAdmin() {
    Navigator.pushNamed(context, AppRouter.admin, arguments: widget.user);
  }

  Widget _buildAdminDashboard() {
    return AdminDashboard(user: widget.user!);
  }

  Widget _buildClientsManagement() {
    return const DatabaseCheckScreen();
  }

  Widget _buildResponsibleDashboard() {
    return ResponsibleDashboard(user: widget.user!);
  }

  Widget _buildContactDashboard() {
    return ContactDashboard(user: widget.user!);
  }

  Widget _buildProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue,
            child: Text(
              widget.user?.firstName.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(fontSize: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.user?.fullName ?? 'Пользователь',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.user?.roleDisplayName ?? '',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRouter.auth);
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Раздел "Оборудование"',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Будет доступен в следующем обновлении',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _navigateToEquipment(),
            child: const Text('Открыть полную версию'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Раздел "Заявки"',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Будет доступен в следующем обновлении',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _navigateToRequests(),
            child: const Text('Открыть полную версию'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Панель администратора',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Будет доступна в следующем обновлении',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _navigateToAdmin(),
            child: const Text('Открыть полную версию'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('T-Co Service'),
            Text(
              widget.user!.roleDisplayName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // Уведомления
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(user: widget.user!),
                    ),
                  ).then((_) => _loadUnreadNotifications());
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Профиль пользователя
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue,
                  child: Text(
                    widget.user!.firstName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.user!.firstName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.user!.roleDisplayName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Навигационные вкладки
          Container(
            color: Colors.white,
            child: Row(
              children: _navigationItems.asMap().entries.map((entry) {
                int index = entry.key;
                NavigationItem item = entry.value;
                bool isSelected = _selectedIndex == index;
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? Colors.blue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected ? Colors.blue : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? Colors.blue : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Контент
          Expanded(
            child: _navigationItems.isNotEmpty
                ? _navigationItems[_selectedIndex].builder()
                : const Center(child: Text('Нет доступных разделов')),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;

  NavigationItem(this.label, this.icon, this.builder);
}