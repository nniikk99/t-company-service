import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _userRole;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role');
      _userName = 'Александр Петров'; // Демо-данные
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('client_id');
    await prefs.remove('is_logged_in');

    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Сервисная служба'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Выйти'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Приветствие
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue,
                      child: Text(
                        _userName?.substring(0, 1).toUpperCase() ?? 'А',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добро пожаловать,',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            _userName ?? 'Пользователь',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Навигационные карточки
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildNavCard(
                    icon: Icons.build,
                    title: 'Оборудование',
                    subtitle: 'Управление техникой',
                    onTap: () => Navigator.pushNamed(context, '/equipment'),
                  ),
                  _buildNavCard(
                    icon: Icons.assignment,
                    title: 'Заявки',
                    subtitle: 'Сервисные заявки',
                    onTap: () => Navigator.pushNamed(context, '/requests'),
                  ),
                  if (_userRole == 'admin') ...[
                    _buildNavCard(
                      icon: Icons.admin_panel_settings,
                      title: 'Админ-панель',
                      subtitle: 'Управление системой',
                      onTap: () => Navigator.pushNamed(context, '/admin'),
                    ),
                    _buildNavCard(
                      icon: Icons.analytics,
                      title: 'Анализ',
                      subtitle: 'Отчеты и статистика',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Раздел в разработке')),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Быстрые действия
            if (_userRole != 'admin') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Быстрые действия',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/requests');
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Новая заявка'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/equipment');
                                },
                                icon: const Icon(Icons.build),
                                label: const Text('Оборудование'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
