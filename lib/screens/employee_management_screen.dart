import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/site.dart';
import '../services/supabase_service.dart';

class EmployeeManagementScreen extends StatefulWidget {
  final User responsibleUser;

  const EmployeeManagementScreen({
    super.key,
    required this.responsibleUser,
  });

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  List<User> _employees = [];
  List<Site> _sites = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Загружаем сотрудников и площадки параллельно
      print('🔍 EmployeeManagementScreen: companyId = ${widget.responsibleUser.companyId}');
      print('🔍 EmployeeManagementScreen: companyInn = ${widget.responsibleUser.companyInn}');
      
      final futures = await Future.wait([
        SupabaseService.getCompanyEmployees(
          companyId: widget.responsibleUser.companyId,
          companyInn: widget.responsibleUser.companyInn,
        ),
        SupabaseService.getSites(widget.responsibleUser.companyId!),
      ]);

      setState(() {
        _employees = futures[0] as List<User>;
        _sites = futures[1] as List<Site>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки данных: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _assignSiteToEmployee(User employee, Site site) async {
    try {
      await SupabaseService.assignSiteToEmployee(
        employee.id,
        site.id,
        widget.responsibleUser.id,
      );
      
      // Принудительно обновляем данные сотрудника из базы данных
      final refreshedEmployee = await SupabaseService.refreshUserData(employee.id);
      
      // Обновляем локальное состояние
      setState(() {
        if (refreshedEmployee != null) {
          final index = _employees.indexWhere((e) => e.id == employee.id);
          if (index != -1) {
            _employees[index] = refreshedEmployee;
          }
        } else {
          // Fallback к локальному обновлению
          final updatedEmployee = employee.copyWith(
            assignedSiteIds: [...(employee.assignedSiteIds ?? []), site.id],
          );
          final index = _employees.indexWhere((e) => e.id == employee.id);
          if (index != -1) {
            _employees[index] = updatedEmployee;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Площадка "${site.name}" назначена ${employee.fullName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка назначения площадки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unassignSiteFromEmployee(User employee, Site site) async {
    try {
      await SupabaseService.unassignSiteFromEmployee(
        employee.id,
        site.id,
        widget.responsibleUser.id,
      );
      
      // Принудительно обновляем данные сотрудника из базы данных
      final refreshedEmployee = await SupabaseService.refreshUserData(employee.id);
      
      // Обновляем локальное состояние
      setState(() {
        if (refreshedEmployee != null) {
          final index = _employees.indexWhere((e) => e.id == employee.id);
          if (index != -1) {
            _employees[index] = refreshedEmployee;
          }
        } else {
          // Fallback к локальному обновлению
          final updatedSites = List<String>.from(employee.assignedSiteIds ?? []);
          updatedSites.remove(site.id);
          final updatedEmployee = employee.copyWith(assignedSiteIds: updatedSites);
          final index = _employees.indexWhere((e) => e.id == employee.id);
          if (index != -1) {
            _employees[index] = updatedEmployee;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Площадка "${site.name}" отменена у ${employee.fullName}'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отмены назначения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSiteAssignmentDialog(User employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Назначение площадок: ${employee.fullName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Роль: ${employee.roleDisplayName}'),
              const SizedBox(height: 16),
              const Text('Доступные площадки:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sites.length,
                  itemBuilder: (context, index) {
                    final site = _sites[index];
                    final isAssigned = employee.assignedSiteIds?.contains(site.id) == true;
                    
                    return ListTile(
                      leading: Icon(
                        isAssigned ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isAssigned ? Colors.green : Colors.grey,
                      ),
                      title: Text(site.name),
                      subtitle: Text(site.address ?? 'Адрес не указан'),
                      trailing: isAssigned
                          ? ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _unassignSiteFromEmployee(employee, site);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Отменить'),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _assignSiteToEmployee(employee, site);
                              },
                              child: const Text('Назначить'),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(User employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить роль: ${employee.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Текущая роль: ${employee.roleDisplayName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Выберите новую роль:'),
            const SizedBox(height: 12),
            _buildRoleOption(employee, UserRole.siteManager, 'Менеджер площадки', Colors.green),
            _buildRoleOption(employee, UserRole.operatorPM, 'Оператор ПМ', Colors.blue),
            _buildRoleOption(employee, UserRole.engineer, 'Инженер', Colors.orange),
          ],
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

  Widget _buildRoleOption(User employee, UserRole role, String roleName, Color color) {
    final isCurrentRole = employee.role == role;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        radius: 16,
        child: Icon(
          isCurrentRole ? Icons.check : Icons.person,
          color: Colors.white,
          size: 18,
        ),
      ),
      title: Text(roleName),
      subtitle: isCurrentRole ? const Text('Текущая роль') : null,
      enabled: !isCurrentRole,
      onTap: isCurrentRole ? null : () {
        Navigator.pop(context);
        _changeEmployeeRole(employee, role);
      },
    );
  }

  Future<void> _changeEmployeeRole(User employee, UserRole newRole) async {
    try {
      await SupabaseService.changeEmployeeRole(
        employee.id,
        _roleToString(newRole),
        widget.responsibleUser.id,
      );
      
      // Обновляем данные сотрудника из базы данных
      final refreshedEmployee = await SupabaseService.refreshUserData(employee.id);
      
      // Обновляем локальное состояние
      setState(() {
        if (refreshedEmployee != null) {
          final index = _employees.indexWhere((e) => e.id == employee.id);
          if (index != -1) {
            _employees[index] = refreshedEmployee;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Роль ${employee.fullName} изменена на ${_getRoleDisplayName(newRole)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка изменения роли: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.siteManager:
        return 'siteManager';
      case UserRole.operatorPM:
        return 'operatorPM';
      case UserRole.engineer:
        return 'engineer';
      default:
        return 'operatorPM';
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.siteManager:
        return 'Менеджер площадки';
      case UserRole.operatorPM:
        return 'Оператор ПМ';
      case UserRole.engineer:
        return 'Инженер';
      default:
        return 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Управление сотрудниками'),
            Text(
              '${widget.responsibleUser.companyName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Информация о компании
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Информация о компании',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Компания: ${widget.responsibleUser.companyName}'),
                          Text('ИНН: ${widget.responsibleUser.companyInn}'),
                          Text('Площадок: ${_sites.length}'),
                          Text('Сотрудников: ${_employees.length}'),
                        ],
                      ),
                    ),
                    
                    // Список сотрудников
                    Expanded(
                      child: _employees.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'Сотрудники не найдены',
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'В компании нет менеджеров площадок или операторов ПМ',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _employees.length,
                              itemBuilder: (context, index) {
                                final employee = _employees[index];
                                final assignedSitesCount = employee.assignedSiteIds?.length ?? 0;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getRoleColor(employee.role),
                                      child: Text(
                                        '${employee.firstName[0]}${employee.lastName[0]}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(employee.fullName),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(employee.roleDisplayName),
                                        Text('Назначено площадок: $assignedSitesCount'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.swap_horiz),
                                          tooltip: 'Изменить роль',
                                          onPressed: () => _showChangeRoleDialog(employee),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _showSiteAssignmentDialog(employee),
                                          child: const Text('Управлять'),
                                        ),
                                      ],
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

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.siteManager:
        return Colors.green;
      case UserRole.operatorPM:
        return Colors.blue;
      case UserRole.engineer:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}