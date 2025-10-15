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
      
    } catch (e) {
      print('Ошибка загрузки данных: $e');
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
                            child: Text(
                              '${company['name']} (ИНН: ${company['inn']})',
                              style: const TextStyle(fontSize: 14),
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
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
}
