import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import 'main_screen.dart';

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
      final usersJson = await SupabaseService.getAllUsers();
      
      final List<User> users = usersJson.map((json) {
        return User.fromJson(json);
      }).toList();
      
      // Исключаем текущего админа из списка (чтобы случайно себе роль не поменять)
      final filteredUsers = users.where((user) => 
        user.id != widget.adminUser.id
      ).toList();
      
      setState(() {
        _users = filteredUsers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.pendingApproval: return 'Ожидает подтверждения';
      case UserRole.operatorPM: return 'Оператор ПМ';
      case UserRole.engineer: return 'Инженер';
      case UserRole.siteManager: return 'Менеджер площадки';
      case UserRole.companyResponsible: return 'Ответственное лицо';
      case UserRole.supplier: return 'Поставщик';
      case UserRole.administrator: return 'Администратор';
      default: return 'Пользователь';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.administrator:
        return Colors.red;
      case UserRole.companyResponsible:
        return Colors.orange;
      case UserRole.siteManager:
        return Colors.blue;
      case UserRole.engineer:
        return Colors.teal;
      case UserRole.operatorPM:
        return Colors.indigo;
      case UserRole.supplier:
        return Colors.purple;
      case UserRole.pendingApproval:
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  List<User> get _filteredUsers {
    var filtered = _users;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final query = _searchQuery.toLowerCase();
        return user.fullName.toLowerCase().contains(query) || 
               user.email.toLowerCase().contains(query) ||
               user.phone.toLowerCase().contains(query);
      }).toList();
    }
    if (_filterRole != null) {
      filtered = filtered.where((user) => user.role == _filterRole).toList();
    }
    return filtered;
  }

  void _showRoleChangeDialog(User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Сменить роль: ${user.fullName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: UserRole.values.map((role) {
                if (role == UserRole.clientManager || 
                    role == UserRole.clientResponsible || role == UserRole.contactPerson) {
                  return const SizedBox.shrink(); // Пропускаем старые роли
                }
                return ListTile(
                  title: Text(_getRoleDisplayName(role)),
                  leading: Radio<UserRole>(
                    value: role,
                    groupValue: user.role,
                    onChanged: (newRole) async {
                      if (newRole != null) {
                        Navigator.pop(context);
                        await _updateUserRole(user.id, newRole);
                      }
                    },
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateUserRole(user.id, role);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateUserRole(String userId, UserRole role) async {
    setState(() => _isLoading = true);
    try {
      final roleStr = role.toString().split('.').last;
      await SupabaseService.updateUserProfile(userId: userId, role: roleStr);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Роль успешно обновлена'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _impersonateUser(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          user: user,
          adminUser: widget.adminUser, // Позволяет вернуться обратно
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Управление пользователями'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Имя, Email или телефон...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<UserRole?>(
                    icon: Icon(
                      _filterRole == null ? Icons.filter_list : Icons.filter_alt,
                      color: const Color(0xFF2563EB),
                    ),
                    onSelected: (role) => setState(() => _filterRole = role),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: null,
                        child: Text('Все роли'),
                      ),
                      ...UserRole.values
                          .where((r) => ![UserRole.clientManager, UserRole.clientResponsible, UserRole.contactPerson].contains(r))
                          .map((role) => PopupMenuItem(
                                value: role,
                                child: Text(_getRoleDisplayName(role)),
                              )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (_filterRole != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(_getRoleDisplayName(_filterRole!)),
                    onDeleted: () => setState(() => _filterRole = null),
                    backgroundColor: const Color(0xFFEFF6FF),
                    labelStyle: const TextStyle(color: Color(0xFF2563EB), fontSize: 12),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                ? const Center(child: Text('Пользователи не найдены'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _impersonateUser(user),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                                  child: Text(
                                    user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: _getRoleColor(user.role), 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            user.fullName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(user.role).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getRoleDisplayName(user.role),
                                              style: TextStyle(
                                                color: _getRoleColor(user.role),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${user.email} • ${user.phone}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 20),
                                  onPressed: () => _showRoleChangeDialog(user),
                                  tooltip: 'Сменить роль',
                                ),
                              ],
                            ),
                          ),
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
