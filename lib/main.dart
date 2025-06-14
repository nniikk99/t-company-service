import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;
import 'dart:html' as html;
import 'models/equipment.dart';
import 'models/user.dart';
import 'models/service_request.dart';
import 'services/telegram_webapp_service.dart';
import 'services/storage_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await supabase.Supabase.initialize(
    url: "https://kwunhuzfnjpcoeusnxzy.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NDA0MzYxOSwiZXhwIjoyMDU5NjE5NjE5fQ.JAn2aQ4dCcA64HHExVCDzaKOv1MtSTmlF7pPEn0CUlU",
  );

  final storageService = StorageService(supabase.Supabase.instance.client);
  runApp(MyApp(storageService: storageService));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;

  const MyApp({
    super.key,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    TelegramWebAppService.init();
    return MaterialApp(
      title: 'T-Company Service',
      theme: TelegramWebAppService.getTheme(),
      home: LoginPage(storageService: storageService),
    );
  }
}

class LoginPage extends StatefulWidget {
  final StorageService storageService;

  const LoginPage({
    super.key,
    required this.storageService,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _innController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'T-Company Service',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _innController,
                  decoration: const InputDecoration(
                    labelText: 'ИНН',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите ИНН';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите пароль';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Запомнить меня'),
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        final users = await widget.storageService.loadUsers();
        final user = users.values.firstWhere(
          (u) => u['inn'] == _innController.text && u['password'] == _passwordController.text,
          orElse: () => throw Exception('Неверный ИНН или пароль'),
        );

        if (_rememberMe) {
          await widget.storageService.setRememberMe(
            _innController.text,
            _passwordController.text,
          );
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => UniversalHomePage(
              user: User.fromJson(user),
              storageService: widget.storageService,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class UniversalHomePage extends StatefulWidget {
  final User user;
  final User? adminUser;
  final StorageService storageService;

  const UniversalHomePage({
    super.key,
    required this.user,
    required this.storageService,
    this.adminUser,
  });

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  int _selectedIndex = 0;
  List<ServiceRequest> serviceRequests = [];
  List<Equipment> equipmentList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final users = await widget.storageService.loadUsers();
      final equipment = await widget.storageService.loadEquipment();
      setState(() {
        equipmentList = equipment;
        _loading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _loading = false);
    }
  }

  Future<List<User>> getAllUsers() async {
    final users = await widget.storageService.loadUsers();
    return users.values.map((u) => User.fromJson(u)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.role == UserRole.admin;
    final isEngineer = widget.user.role == UserRole.engineer;
    final isClient = widget.user.role == UserRole.client;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'T-Company Service — Админ' : 'T-Company Service'),
        actions: [
          if (widget.adminUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => UniversalHomePage(
                        user: widget.adminUser!,
                        storageService: widget.storageService,
                      ),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                label: const Text('Вернуться в админку', style: TextStyle(color: Colors.blue)),
              ),
            ),
        ],
      ),
      drawer: isAdmin ? _buildAdminDrawer(context) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                if (!isEngineer) _buildEquipmentList(),
                _buildRequestsList(),
                _buildStatistics(),
                _buildProfile(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          if (!isEngineer)
            const NavigationDestination(
              icon: Icon(Icons.precision_manufacturing),
              label: 'Оборудование',
            ),
          const NavigationDestination(
            icon: Icon(Icons.assignment),
            label: 'Заявки',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Аналитика',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, size: 48, color: Colors.blue),
                const SizedBox(height: 8),
                Text(widget.user.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.user.email, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.supervisor_account),
            title: const Text('Админ-панель'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminPanelPage(
                    onImpersonate: (user) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => UniversalHomePage(
                            user: user,
                            adminUser: widget.user,
                            storageService: widget.storageService,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => LoginPage(storageService: widget.storageService),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentList() {
    return Center(child: Text('Оборудование (заглушка)'));
  }

  Widget _buildRequestsList() {
    if (serviceRequests.isEmpty) {
      return const Center(child: Text('Заявок нет'));
    }
    return ListView.builder(
      itemCount: serviceRequests.length,
      itemBuilder: (context, index) {
        final request = serviceRequests[index];
        return ListTile(
          title: Text(request.title),
          subtitle: Text(request.description),
        );
      },
    );
  }

  Widget _buildStatistics() {
    return const Center(child: Text('Статистика (заглушка)'));
  }

  Widget _buildProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${widget.user.lastName} ${widget.user.firstName}'),
          Text(widget.user.email),
          Text(widget.user.phone),
          Text(widget.user.position),
        ],
      ),
    );
  }
}

class AdminPanelPage extends StatefulWidget {
  final void Function(User user) onImpersonate;

  const AdminPanelPage({
    super.key,
    required this.onImpersonate,
  });

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  List<User> users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final storageService = StorageService(supabase.Supabase.instance.client);
      final usersMap = await storageService.loadUsers();
      setState(() {
        users = usersMap.values.map((u) => User.fromJson(u)).toList();
        _loading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      final storageService = StorageService(supabase.Supabase.instance.client);
      final user = users.firstWhere((u) => u.id == userId);
      final updatedUser = User(
        id: user.id,
        inn: user.inn,
        companyName: user.companyName,
        lastName: user.lastName,
        firstName: user.firstName,
        middleName: user.middleName,
        position: user.position,
        email: user.email,
        phone: user.phone,
        password: user.password,
        role: role,
        equipment: user.equipment,
      );
      await storageService.updateUser(updatedUser);
      await _loadUsers();
    } catch (e) {
      print('Error updating user role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
      ),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text('${user.lastName} ${user.firstName}'),
            subtitle: Text(user.email),
            trailing: PopupMenuButton<UserRole>(
              onSelected: (role) => updateUserRole(user.id, role),
              itemBuilder: (context) => UserRole.values
                  .map(
                    (role) => PopupMenuItem(
                      value: role,
                      child: Text(role.toString().split('.').last),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}