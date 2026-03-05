import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';

enum ManagementView { mainMenu, companies, users, equipment }

class DatabaseManagementScreen extends StatefulWidget {
  final User adminUser;

  const DatabaseManagementScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<DatabaseManagementScreen> createState() => _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> {
  ManagementView _currentView = ManagementView.mainMenu;
  
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allCompanies = [];
  List<Map<String, dynamic>> _allModels = [];
  
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getAllUsers(),
        SupabaseService.getAllCompanies(),
        SupabaseService.getAllEquipmentModels(),
      ]);

      setState(() {
        _allUsers = results[0];
        _allCompanies = results[1];
        _allModels = results[2];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading management data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setView(ManagementView view) {
    setState(() {
      _currentView = view;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _deleteItem(String id, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text('Вы уверены, что хотите удалить ${type == "user" ? "пользователя" : type == "company" ? "компанию" : "модель"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (type == 'user') {
        await SupabaseService.deleteUserProfile(id);
      } else if (type == 'company') {
        await SupabaseService.deleteCompany(id);
      } else if (type == 'model') {
        await SupabaseService.deleteEquipmentModel(id);
      }
      
      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Успешно удалено'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_getViewTitle()),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        leading: _currentView != ManagementView.mainMenu 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _setView(ManagementView.mainMenu),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(),
    );
  }

  String _getViewTitle() {
    switch (_currentView) {
      case ManagementView.mainMenu: return 'Управление БД';
      case ManagementView.companies: return 'Компании';
      case ManagementView.users: return 'Пользователи';
      case ManagementView.equipment: return 'Оборудование';
    }
  }

  Widget _buildContent() {
    switch (_currentView) {
      case ManagementView.mainMenu: return _buildMainMenu();
      case ManagementView.companies: return _buildList(ManagementView.companies);
      case ManagementView.users: return _buildList(ManagementView.users);
      case ManagementView.equipment: return _buildList(ManagementView.equipment);
    }
  }

  Widget _buildMainMenu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMenuCard(
            'Компании', 
            '${_allCompanies.length} организаций', 
            Icons.business, 
            () => _setView(ManagementView.companies)
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            'Пользователи', 
            '${_allUsers.length} аккаунтов', 
            Icons.people, 
            () => _setView(ManagementView.users)
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            'Оборудование', 
            '${_allModels.length} моделей', 
            Icons.precision_manufacturing, 
            () => _setView(ManagementView.equipment)
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildList(ManagementView type) {
    List<Map<String, dynamic>> items;
    if (type == ManagementView.companies) {
      items = _allCompanies;
    } else if (type == ManagementView.users) items = _allUsers;
    else items = _allModels;

    final filtered = items.where((item) {
      final query = _searchQuery.toLowerCase();
      if (type == ManagementView.companies) {
        return (item['name'] ?? '').toLowerCase().contains(query) || 
               (item['inn'] ?? '').toLowerCase().contains(query);
      } else if (type == ManagementView.users) {
        final fullName = '${item['first_name']} ${item['last_name']}'.toLowerCase();
        return fullName.contains(query) || (item['email'] ?? '').toLowerCase().contains(query);
      } else {
        final manufacturer = (item['manufacturer'] ?? '').toLowerCase();
        final model = (item['model'] ?? '').toLowerCase();
        return manufacturer.contains(query) || model.contains(query);
      }
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildItemCard(item, type);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, ManagementView type) {
    String title = '';
    String subtitle = '';
    String deleteType = '';
    
    if (type == ManagementView.companies) {
      title = item['name'] ?? 'Без названия';
      subtitle = 'ИНН: ${item['inn'] ?? 'не указан'}';
      deleteType = 'company';
    } else if (type == ManagementView.users) {
      title = '${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'.trim();
      subtitle = '${item['email'] ?? ''} • ${item['role'] ?? ''}';
      deleteType = 'user';
    } else {
      title = '${item['manufacturer'] ?? ''} ${item['model'] ?? ''}';
      subtitle = 'Характеристик: ${(item['specifications'] as Map?)?.length ?? 0}';
      deleteType = 'model';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteItem(item['id'], deleteType),
        ),
      ),
    );
  }
}
