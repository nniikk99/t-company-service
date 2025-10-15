import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import 'main_screen.dart';
import 'site_assignment_screen.dart';

class ClientManagementScreen extends StatefulWidget {
  final User adminUser;

  const ClientManagementScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  List<User> _users = [];
  Map<String, Map<String, dynamic>> _companies = {}; // company_id -> company data
  bool _isLoading = true;
  String _searchQuery = '';
  UserRole? _filterRole;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      // Получаем пользователей из локального хранилища
      final users = await StorageService.getUsers();
      
      // Исключаем текущего админа и инженеров из списка
      final filteredUsers = users.where((user) => 
        user.id != widget.adminUser.id && 
        user.role != UserRole.engineer
      ).toList();
      
      // Загружаем информацию о компаниях
      await _loadCompanies(filteredUsers);
      
      setState(() {
        _users = filteredUsers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCompanies(List<User> users) async {
    try {
      // Получаем все компании
      final companies = await SupabaseService.getAllCompanies();
      
      // Создаем мапу для быстрого доступа
      final companiesMap = <String, Map<String, dynamic>>{};
      for (var company in companies) {
        companiesMap[company['id']] = company;
      }
      
      setState(() {
        _companies = companiesMap;
      });
    } catch (e) {
      print('Error loading companies: $e');
    }
  }

  String _getOrgTypeDisplayName(String? orgType) {
    switch (orgType) {
      case 'customer':
        return 'Заказчик';
      case 'supplier':
        return 'Поставщик';
      case 'service_partner':
        return 'Сервисный партнер';
      default:
        return '';
    }
  }

  String _getOrgTypeIcon(String? orgType) {
    switch (orgType) {
      case 'customer':
        return '🏢';
      case 'supplier':
        return '📦';
      case 'service_partner':
        return '🔧';
      default:
        return '';
    }
  }

  List<User> get _filteredUsers {
    var filtered = _users;

    // Фильтр по поисковому запросу
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
        final companyName = user.companyName?.toLowerCase() ?? '';
        final phone = user.phone.toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        return fullName.contains(query) || 
               companyName.contains(query) || 
               phone.contains(query);
      }).toList();
    }

    // Фильтр по роли
    if (_filterRole != null) {
      filtered = filtered.where((user) => user.role == _filterRole).toList();
    }

    return filtered;
  }

  Future<void> _changeUserRole(User user, UserRole newRole) async {
    try {
      // Обновляем роль пользователя
      final updatedUser = user.copyWith(role: newRole);
      
      // Сохраняем в локальное хранилище
      await StorageService.saveUser(updatedUser);
      
      // Обновляем список
      await _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Роль пользователя "${user.firstName} ${user.lastName}" изменена на ${_getRoleDisplayName(newRole)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка при изменении роли: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.pendingApproval:
        return 'Ожидает подтверждения';
      case UserRole.operatorPM:
        return 'Оператор ПМ';
      case UserRole.engineer:
        return 'Инженер';
      case UserRole.siteManager:
        return 'Менеджер площадки';
      case UserRole.companyResponsible:
        return 'Ответственное лицо';
      case UserRole.supplier:
        return 'Поставщик';
      case UserRole.superAdmin:
        return 'Супер-администратор';
      case UserRole.administrator:
        return 'Администратор';
      // Старые роли (для совместимости)
      case UserRole.admin:
        return 'Администратор';
      case UserRole.clientManager:
        return 'Менеджер клиента';
      case UserRole.clientResponsible:
        return 'Ответственный клиента';
      case UserRole.contactPerson:
        return 'Контактное лицо';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.pendingApproval:
        return Colors.grey;
      case UserRole.operatorPM:
        return Colors.blue;
      case UserRole.engineer:
        return Colors.teal;
      case UserRole.siteManager:
        return Colors.green;
      case UserRole.companyResponsible:
        return Colors.orange;
      case UserRole.supplier:
        return Colors.orange;
      case UserRole.superAdmin:
        return Colors.red;
      case UserRole.administrator:
        return Colors.red;
      // Старые роли (для совместимости)
      case UserRole.admin:
        return Colors.purple;
      case UserRole.clientManager:
        return Colors.teal;
      case UserRole.clientResponsible:
        return Colors.indigo;
      case UserRole.contactPerson:
        return Colors.brown;
    }
  }

  void _showRoleChangeDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить роль: ${user.firstName} ${user.lastName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Компания: ${user.companyName ?? 'Не указана'}'),
              const SizedBox(height: 16),
              const Text('Выберите новую роль:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Используем Flexible для прокрутки
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Только новые роли
                      ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getRoleColor(UserRole.pendingApproval),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(_getRoleDisplayName(UserRole.pendingApproval)),
                        selected: user.role == UserRole.pendingApproval,
                        onTap: () {
                          Navigator.pop(context);
                          _changeUserRole(user, UserRole.pendingApproval);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getRoleColor(UserRole.operatorPM),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(_getRoleDisplayName(UserRole.operatorPM)),
                        selected: user.role == UserRole.operatorPM,
                        onTap: () {
                          Navigator.pop(context);
                          _changeUserRole(user, UserRole.operatorPM);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getRoleColor(UserRole.siteManager),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(_getRoleDisplayName(UserRole.siteManager)),
                        selected: user.role == UserRole.siteManager,
                        onTap: () {
                          Navigator.pop(context);
                          _changeUserRole(user, UserRole.siteManager);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getRoleColor(UserRole.companyResponsible),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(_getRoleDisplayName(UserRole.companyResponsible)),
                        selected: user.role == UserRole.companyResponsible,
                        onTap: () {
                          Navigator.pop(context);
                          _changeUserRole(user, UserRole.companyResponsible);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getRoleColor(UserRole.engineer),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(_getRoleDisplayName(UserRole.engineer)),
                        selected: user.role == UserRole.engineer,
                        onTap: () {
                          Navigator.pop(context);
                          _changeUserRole(user, UserRole.engineer);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getRoleColor(UserRole.superAdmin),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(_getRoleDisplayName(UserRole.superAdmin)),
                        selected: user.role == UserRole.superAdmin,
                        onTap: () {
                          Navigator.pop(context);
                          _changeUserRole(user, UserRole.superAdmin);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  void _loginAsUser(User user) {
    // Сохраняем текущего админа для возврата
    final adminUser = widget.adminUser;
    
    // Переходим в главное меню пользователя (оборудование)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          user: user,
          initialView: ViewType.equipment, // Начинаем с оборудования
          adminUser: adminUser, // Передаем админа для возврата
        ),
      ),
    );
    
    // Показываем уведомление
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔑 Вход в аккаунт: ${user.firstName} ${user.lastName}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Назад к админу',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ClientManagementScreen(adminUser: adminUser),
              ),
            );
          },
        ),
      ),
    );
  }

  void _assignSitesToManager(User manager) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SiteAssignmentScreen(
          manager: manager,
          currentUser: widget.adminUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление клиентами'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить список',
          ),
        ],
      ),
      body: Column(
        children: [
          // Поиск и фильтры
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Поиск
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Поиск по имени, компании или телефону...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Фильтр по ролям
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Все роли'),
                        selected: _filterRole == null,
                        onSelected: (selected) {
                          setState(() {
                            _filterRole = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...UserRole.values.where((role) => 
                        role == UserRole.pendingApproval ||
                        role == UserRole.operatorPM ||
                        role == UserRole.siteManager ||
                        role == UserRole.companyResponsible ||
                        role == UserRole.superAdmin
                      ).map((role) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getRoleDisplayName(role)),
                          selected: _filterRole == role,
                          onSelected: (selected) {
                            setState(() {
                              _filterRole = selected ? role : null;
                            });
                          },
                          selectedColor: _getRoleColor(role).withOpacity(0.3),
                          checkmarkColor: _getRoleColor(role),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Список пользователей
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Пользователи не найдены',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Попробуйте изменить фильтры поиска',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRoleColor(user.role),
                                child: Text(
                                  '${user.firstName[0]}${user.lastName[0]}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text('${user.firstName} ${user.lastName}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.companyName ?? 'Компания не указана'),
                                  Text(user.phone),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      // Бейдж роли пользователя
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(user.role).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getRoleColor(user.role),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _getRoleDisplayName(user.role),
                                          style: TextStyle(
                                            color: _getRoleColor(user.role),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      // Бейдж типа организации
                                      if (user.companyId != null && _companies.containsKey(user.companyId))
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey.shade400,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '${_getOrgTypeIcon(_companies[user.companyId]!['org_type'])} ${_getOrgTypeDisplayName(_companies[user.companyId]!['org_type'])}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'change_role') {
                                    _showRoleChangeDialog(user);
                                  } else if (value == 'login_as') {
                                    _loginAsUser(user);
                                  } else if (value == 'assign_sites') {
                                    _assignSitesToManager(user);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'login_as',
                                    child: Row(
                                      children: [
                                        Icon(Icons.login, size: 20),
                                        SizedBox(width: 8),
                                        Text('Войти в аккаунт'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'change_role',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Изменить роль'),
                                      ],
                                    ),
                                  ),
                                  if (user.role == UserRole.siteManager)
                                    const PopupMenuItem(
                                      value: 'assign_sites',
                                      child: Row(
                                        children: [
                                          Icon(Icons.location_on, size: 20),
                                          SizedBox(width: 8),
                                          Text('Назначить площадки'),
                                        ],
                                      ),
                                    ),
                                ],
                                child: const Icon(Icons.more_vert),
                              ),
                              onTap: () => _loginAsUser(user),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
