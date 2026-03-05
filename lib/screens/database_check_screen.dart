import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as AppUserModel;
import '../services/app_router.dart';

class DatabaseCheckScreen extends StatefulWidget {
  const DatabaseCheckScreen({super.key});

  @override
  State<DatabaseCheckScreen> createState() => _DatabaseCheckScreenState();
}

class _DatabaseCheckScreenState extends State<DatabaseCheckScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _equipmentModels = [];
  List<Map<String, dynamic>> _brands = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Загружаем пользователей
      final usersResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('*');
      _users = List<Map<String, dynamic>>.from(usersResponse);
      
      // Загружаем компании
      final companiesResponse = await Supabase.instance.client
          .from('companies')
          .select('*');
      _companies = List<Map<String, dynamic>>.from(companiesResponse);
      
      // Загружаем модели оборудования
      final modelsResponse = await Supabase.instance.client
          .from('equipment_models')
          .select('*');
      _equipmentModels = List<Map<String, dynamic>>.from(modelsResponse);
      
      // Загружаем бренды
      try {
        final brandsResponse = await Supabase.instance.client
            .from('equipment_brands')
            .select('*')
            .order('created_at', ascending: false);
        _brands = List<Map<String, dynamic>>.from(brandsResponse);
      } catch (e) {
        print('Ошибка загрузки брендов: $e');
        _brands = [];
      }
      
    } catch (e) {
      print('Ошибка загрузки данных: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('Вы уверены, что хотите удалить пользователя "$userName"? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .delete()
          .eq('id', userId);
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пользователь успешно удален'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadData();
    } catch (e) {
      print('Ошибка удаления пользователя: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка удаления: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCompany(String companyId, String companyName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить компанию?'),
        content: Text('Вы уверены, что хотите удалить компанию "$companyName"? Все связанные данные (пользователи, площадки, оборудование) могут быть также удалены или повреждены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('companies')
          .delete()
          .eq('id', companyId);
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Компания успешно удалена'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadData();
    } catch (e) {
      print('Ошибка удаления компании: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка удаления: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBrandStatus(String brandId, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('equipment_brands')
          .update({'status': newStatus})
          .eq('id', brandId);
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Статус успешно изменен на $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    } catch (e) {
      print('Ошибка обновления статуса бренда: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка обновления статуса: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBrand(String brandId, String brandName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товарный знак?'),
        content: Text('Вы уверены, что хотите удалить товарный знак "$brandName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('equipment_brands')
          .delete()
          .eq('id', brandId);
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товарный знак удален'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    } catch (e) {
      print('Ошибка удаления бренда: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка удаления: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fixUserRole(String userId) async {
    setState(() => _isLoading = true);
    
    try {
      // Обновляем роль пользователя до superAdmin
      // Используем raw query если возможно, или обычный update
      // В данном случае мы используем обычный update, надеясь что RLS позволит это сделать
      // (так как мы уже admin, возможно у нас есть права на update своего профиля или других)
      
      // Если RLS блокирует, мы ничего не сможем сделать через клиентское приложение
      // Но попробуем вызвать RPC функцию если она есть, или прямой update
      
      await Supabase.instance.client
          .from('user_profiles')
          .update({'role': 'superAdmin'})
          .eq('id', userId);
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Роль успешно обновлена до superAdmin! Перезайдите в приложение.'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadData();
      
    } catch (e) {
      print('Ошибка обновления роли: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка обновления роли: $e\nПопробуйте выполнить SQL скрипт вручную.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loginAsUser(Map<String, dynamic> userData) {
    try {
      final user = AppUserModel.User.fromJson(userData);
      Navigator.pushReplacementNamed(
        context, 
        AppRouter.dashboard, 
        arguments: user,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка входа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление клиентами'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Компании
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Компании (${_companies.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._companies.map((company) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${company['name']} (ИНН: ${company['inn'] ?? 'нет'})',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteCompany(company['id'], company['name']),
                                  tooltip: 'Удалить компанию',
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Пользователи
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Пользователи (${_users.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._users.map((user) => InkWell(
                            onTap: () => _loginAsUser(user),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${user['first_name']} ${user['last_name']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.login,
                                        size: 16,
                                        color: Color(0xFF4A90E2),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Телефон: ${user['contact_phone'] ?? 'не указан'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    'Email: ${user['email'] ?? 'не указан'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    'Роль: ${user['role'] ?? 'не указана'}',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: user['role'] == 'admin' ? Colors.red : Colors.grey,
                                      fontWeight: user['role'] == 'admin' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (user['role'] == 'admin')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () => _fixUserRole(user['id']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Исправить роль (admin -> superAdmin)'),
                                      ),
                                    ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _deleteUser(user['id'], '${user['first_name']} ${user['last_name']}'),
                                      icon: const Icon(Icons.delete_forever, size: 16, color: Colors.red),
                                      label: const Text('Удалить', style: TextStyle(color: Colors.red, fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Модели оборудования
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Модели оборудования (${_equipmentModels.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_equipmentModels.isEmpty)
                            const Text('Список моделей пуст', style: TextStyle(color: Colors.grey)),
                          ..._equipmentModels.take(10).map((model) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${model['manufacturer']} ${model['model']} (Supplier ID: ${model['supplier_id']})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          )),
                          if (_equipmentModels.length > 10)
                            const Text('...и еще более 10 моделей', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Товарные знаки
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Товарные знаки (${_brands.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_brands.isEmpty)
                            const Text('Список товарных знаков пуст', style: TextStyle(color: Colors.grey)),
                          ..._brands.map((brand) => Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        brand['name'] ?? 'Неизвестно',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    _buildBrandStatusBadge(brand['status']),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supplier ID: ${brand['supplier_id']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (brand['status'] == 'pending' || brand['status'] == 'rejected')
                                      TextButton.icon(
                                        onPressed: () => _updateBrandStatus(brand['id'], 'approved'),
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        label: const Text('Принять', style: TextStyle(color: Colors.green)),
                                      ),
                                    if (brand['status'] == 'pending' || brand['status'] == 'approved')
                                      TextButton.icon(
                                        onPressed: () => _updateBrandStatus(brand['id'], 'rejected'),
                                        icon: const Icon(Icons.close, color: Colors.orange),
                                        label: const Text('Отклонить', style: TextStyle(color: Colors.orange)),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => _deleteBrand(brand['id'], brand['name']),
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text('Удалить', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Кнопка обновления
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Обновить данные'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBrandStatusBadge(String? status) {
    Color color;
    String text;
    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Подтвержден';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Отклонен';
        break;
      case 'pending':
      default:
        color = Colors.orange;
        text = 'На модерации';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
