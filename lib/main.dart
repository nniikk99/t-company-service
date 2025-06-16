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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: "https://kwunhuzfnjpcoeusnxzy.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3dW5odXpmbmpwY29ldXNueHp5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NDA0MzYxOSwiZXhwIjoyMDU5NjE5NjE5fQ.JAn2aQ4dCcA64HHExVCDzaKOv1MtSTmlF7pPEn0CUlU",
  );

  final storageService = StorageService(Supabase.instance.client);
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
  bool _isLoading = false;

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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти'),
                          ),
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
      setState(() => _isLoading = true);
      try {
        print('Attempting login with INN: ${_innController.text}');
        final users = await widget.storageService.loadUsers();
        print('Loaded users: ${users.length}');
        
        final user = users.values.firstWhere(
          (u) => u['inn'] == _innController.text && u['password'] == _passwordController.text,
          orElse: () => throw Exception('Неверный ИНН или пароль'),
        );
        
        print('Found user: ${user['inn']}');

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
        print('Login error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
            NavigationDestination(
              icon: Image.asset('assets/icons/equipment.png', width: 24, height: 24),
              label: 'Оборудование',
            ),
          const NavigationDestination(
            icon: Icon(Icons.assignment),
            label: 'Заявки',
          ),
          NavigationDestination(
            icon: Image.asset('assets/icons/analytics.png', width: 24, height: 24),
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
    final isAdmin = widget.user.role == UserRole.admin;
    List<Equipment> filteredList = equipmentList;
    String filterInn = '';
    String filterModel = '';
    String filterManufacturer = '';
    String filterSerial = '';

    void _showFilterDialog(VoidCallback onFilterChanged) {
      final _innController = TextEditingController(text: filterInn);
      final _modelController = TextEditingController(text: filterModel);
      final _manufacturerController = TextEditingController(text: filterManufacturer);
      final _serialController = TextEditingController(text: filterSerial);
    showDialog(
      context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Фильтр оборудования'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _innController,
                  decoration: const InputDecoration(labelText: 'ИНН компании'),
                  onChanged: (v) {
                    filterInn = v;
                    onFilterChanged();
                  },
                ),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Модель'),
                  onChanged: (v) {
                    filterModel = v;
                    onFilterChanged();
                  },
                ),
                TextField(
                  controller: _manufacturerController,
                  decoration: const InputDecoration(labelText: 'Производитель'),
                  onChanged: (v) {
                    filterManufacturer = v;
                    onFilterChanged();
                  },
                ),
                TextField(
                  controller: _serialController,
                  decoration: const InputDecoration(labelText: 'Серийный номер'),
                  onChanged: (v) {
                    filterSerial = v;
                    onFilterChanged();
                  },
          ),
        ],
      ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          );
        },
      );
    }

    void _showAddEquipmentDialog() async {
      final _formKey = GlobalKey<FormState>();
    String? selectedManufacturer;
    String? selectedModel;
      String? selectedModification;
      final _addressController = TextEditingController();
      final _contactNameController = TextEditingController();
      final _contactPhoneController = TextEditingController();
      final _contactEmailController = TextEditingController();
      bool showEmail = false;

      final manufacturers = ['Tennant', 'Gadlee', 'IPC', 'T-line', 'Gausium'];
      final models = {
        'Tennant': [
          'T1', 'T2', 'T3', 'T5', 'T500', 'T7', 'T12', 'T15', 'T16', 'M17', 'T20', 'M20'
        ],
        'Gadlee': [
          'GT30', 'GT50 С50', 'GT50 B50', 'GT55 BT50', 'GT70', 'GT110', 'GT180 75RS', 'GT180 B95', 'GT260', 'GTS920', 'GTS1200', 'GTS1450', 'GTS1900'
        ],
        'IPC': [
          'CT15B35', 'CT15C35', 'CT40B50', 'CT40 BT 50', 'CT40C50', 'CT45B50', 'CT51', 'CT71', 'CT80', 'CT90', 'CT110'
        ],
        'T-line': [
          'TLO1500', 'T-Mop', 'T-vac'
        ],
        'Gausium': [
          'ALLYBOT-C2', 'Phantas', 'Beetle', 'Omnie', 'Scrubber 50 Pro', 'Scrubber 75', 'Scrubber 50', 'Vacuum 40 Diffuser'
        ],
      };
      final modifications = {
        'T3': ['43M', '50D'],
        'T5': ['D600', 'D700'],
        'T500': ['D600', 'D700'],
      };

    showDialog(
      context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
          title: const Text('Добавить оборудование'),
                content: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedManufacturer,
                          items: manufacturers.map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m),
                          )).toList(),
                          onChanged: (v) {
                    setState(() {
                              selectedManufacturer = v;
                      selectedModel = null;
                              selectedModification = null;
                    });
                  },
                          decoration: const InputDecoration(labelText: 'Производитель'),
                          validator: (v) => v == null ? 'Выберите производителя' : null,
                ),
                if (selectedManufacturer != null)
                  DropdownButtonFormField<String>(
                    value: selectedModel,
                            items: models[selectedManufacturer]!.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            )).toList(),
                            onChanged: (v) {
                      setState(() {
                                selectedModel = v;
                                selectedModification = null;
                      });
                    },
                            decoration: const InputDecoration(labelText: 'Модель'),
                            validator: (v) => v == null ? 'Выберите модель' : null,
                          ),
                        if (selectedModel != null && modifications[selectedModel] != null)
                DropdownButtonFormField<String>(
                            value: selectedModification,
                            items: modifications[selectedModel]!.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            )).toList(),
                            onChanged: (v) => setState(() => selectedModification = v),
                            decoration: const InputDecoration(labelText: 'Модификация'),
                            validator: (v) => v == null ? 'Выберите модификацию' : null,
                          ),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(labelText: 'Адрес'),
                          validator: (v) => v == null || v.isEmpty ? 'Введите адрес' : null,
                        ),
                        TextFormField(
                          controller: _contactNameController,
                          decoration: const InputDecoration(labelText: 'Контактное лицо (ФИО)'),
                          validator: (v) => v == null || v.isEmpty ? 'Введите ФИО' : null,
                        ),
                        TextFormField(
                          controller: _contactPhoneController,
                          decoration: const InputDecoration(labelText: 'Телефон'),
                          validator: (v) => v == null || v.isEmpty ? 'Введите телефон' : null,
                        ),
                        if (showEmail)
                          TextFormField(
                            controller: _contactEmailController,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: (v) => v == null || v.isEmpty ? 'Введите email' : null,
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() => showEmail = true),
                            child: const Text('Добавить почту'),
                  ),
                ),
              ],
            ),
          ),
                ),
              );
            },
          );
        },
      );
    }

    return Stack(
      children: [
        isAdmin
          ? StatefulBuilder(
              builder: (context, setState) {
                final filtered = equipmentList.where((e) {
                  final byInn = filterInn.isEmpty || e.userId.contains(filterInn);
                  final byModel = filterModel.isEmpty || e.title.toLowerCase().contains(filterModel.toLowerCase());
                  final byManufacturer = filterManufacturer.isEmpty || e.description.toLowerCase().contains(filterManufacturer.toLowerCase());
                  final bySerial = filterSerial.isEmpty || e.serialNumber.toLowerCase().contains(filterSerial.toLowerCase());
                  return byInn && byModel && byManufacturer && bySerial;
                }).toList();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Фильтр'),
                          onPressed: () {
                            _showFilterDialog(() => setState(() {}));
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Оборудование не найдено'))
                          : ListView(
                              children: filtered.map((e) => ListTile(
                                title: Text(e.title),
                                subtitle: Text('ИНН: ${e.userId}\nСерийный: ${e.serialNumber}\n${e.description}'),
                              )).toList(),
                            ),
                    ),
                  ],
                );
              },
            )
          : (equipmentList.where((e) => e.userId == widget.user.id).isEmpty
              ? const Center(child: Text('Оборудование не найдено'))
              : ListView(
                  children: equipmentList.where((e) => e.userId == widget.user.id).map((e) => ListTile(
                    title: Text(e.title),
                    subtitle: Text('Серийный: ${e.serialNumber}\n${e.description}'),
                  )).toList(),
                )
            ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showAddEquipmentDialog,
            child: const Icon(Icons.add),
            tooltip: 'Добавить оборудование',
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    final isAdmin = widget.user.role == UserRole.admin;
    final isEngineer = widget.user.role == UserRole.engineer;
    final isClient = widget.user.role == UserRole.client;

    // Разделяем заявки на активные и архивные
    final activeRequests = serviceRequests.where((r) => !r.isArchived).toList();
    final archivedRequests = serviceRequests.where((r) => r.isArchived).toList();

    // Для фильтрации по вкладкам
    int tabIndex = 0;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Активные'),
              Tab(text: 'Архив'),
            ],
            onTap: (i) => tabIndex = i,
          ),
          Expanded(
            child: TabBarView(
        children: [
                // Активные заявки
                _buildRequestListView(activeRequests, isAdmin, isEngineer, isClient),
                // Архивные заявки
                _buildRequestListView(archivedRequests, isAdmin, isEngineer, isClient, isArchive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestListView(List<ServiceRequest> requests, bool isAdmin, bool isEngineer, bool isClient, {bool isArchive = false}) {
    if (requests.isEmpty) {
      return const Center(child: Text('Заявок нет'));
    }
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(req.title),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Статус: ${_statusText(req.status)}'),
                if (req.engineerId != null) Text('Инженер: ${_getEngineerName(req.engineerId!)}'),
                if (req.visitDate != null) Text('Дата визита: ${_formatDate(req.visitDate!)}'),
                if (req.invoiceUrl != null && req.invoiceUrl!.isNotEmpty)
                  Row(
                    children: [
                      Text('Сумма: '),
                      Text(req.invoiceAmount?.toStringAsFixed(2) ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          final url = req.invoiceUrl!;
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                          }
                        },
                        child: const Text('Скачать счёт'),
                      ),
                    ],
                  ),
                if (isAdmin && isArchive && (req.invoiceUrl == null || req.invoiceUrl!.isEmpty))
                  ElevatedButton(
                    onPressed: () => _showAttachInvoiceDialog(req),
                    child: const Text('Прикрепить счёт'),
                  ),
                if (isAdmin && isArchive && req.invoiceUrl != null && req.invoiceUrl!.isNotEmpty)
                  Row(
                    children: [
                      req.isPaid
                        ? const Text('Оплачено', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                        : ElevatedButton(
                            onPressed: () => _markRequestPaid(req),
                            child: const Text('Отметить как оплачено'),
                          ),
                    ],
                  ),
                if (!isAdmin && isArchive && req.invoiceUrl != null && req.invoiceUrl!.isNotEmpty)
                  Text(req.isPaid ? 'Оплачено' : 'Не оплачено', style: TextStyle(color: req.isPaid ? Colors.green : Colors.red)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusText(ServiceRequestStatus status) {
    switch (status) {
      case ServiceRequestStatus.newRequest:
        return 'Новая заявка';
      case ServiceRequestStatus.assigned:
        return 'Назначен инженер';
      case ServiceRequestStatus.completed:
        return 'Выполнена';
    }
  }

  String _getEngineerName(String engineerId) {
    // Здесь должен быть поиск по списку пользователей
    // Можно хранить список пользователей в состоянии UniversalHomePage
    // Пример:
    // final engineer = allUsers.firstWhere((u) => u.id == engineerId, orElse: () => null);
    // return engineer != null ? '${engineer.lastName} ${engineer.firstName}' : engineerId;
    return engineerId;
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showAssignEngineerDialog(ServiceRequest req) async {
    final usersMap = await widget.storageService.loadUsers();
    final engineers = usersMap.values.map((u) => User.fromJson(u)).where((u) => u.role == UserRole.engineer).toList();
    String? selectedEngineerId;
    DateTime? selectedDate;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Назначить инженера'),
              content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                  DropdownButtonFormField<String>(
                    value: selectedEngineerId,
                    items: engineers.map((e) => DropdownMenuItem(
                      value: e.id,
                      child: Text('${e.lastName} ${e.firstName}'),
                    )).toList(),
                    onChanged: (v) => setState(() => selectedEngineerId = v),
                    decoration: const InputDecoration(labelText: 'Инженер'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                    child: Text(selectedDate == null ? 'Выбрать дату визита' : _formatDate(selectedDate!)),
                  ),
                ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: selectedEngineerId != null && selectedDate != null
                      ? () async {
                          final updated = ServiceRequest(
                            id: req.id,
                            title: req.title,
                            description: req.description,
                            equipmentId: req.equipmentId,
                            userId: req.userId,
                            createdAt: req.createdAt,
                            status: ServiceRequestStatus.assigned,
                            engineerId: selectedEngineerId,
                            visitDate: selectedDate,
                            isArchived: false,
                          );
                          await widget.storageService.updateServiceRequest(updated);
                          setState(() {
                            final idx = serviceRequests.indexWhere((r) => r.id == req.id);
                            if (idx != -1) serviceRequests[idx] = updated;
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Назначить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _markRequestCompleted(ServiceRequest req) async {
    final updated = ServiceRequest(
      id: req.id,
      title: req.title,
      description: req.description,
      equipmentId: req.equipmentId,
      userId: req.userId,
      createdAt: req.createdAt,
      status: ServiceRequestStatus.completed,
      engineerId: req.engineerId,
      visitDate: req.visitDate,
      isArchived: true,
    );
    await widget.storageService.updateServiceRequest(updated);
    setState(() {
      final idx = serviceRequests.indexWhere((r) => r.id == req.id);
      if (idx != -1) serviceRequests[idx] = updated;
    });
  }

  void _showAttachInvoiceDialog(ServiceRequest req) async {
    String? pdfUrl;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Прикрепить счёт'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Ссылка на PDF (drag-n-drop или вставьте ссылку)'),
                    onChanged: (v) => pdfUrl = v,
                  ),
                  Container(
                    height: 80,
                    color: Colors.grey[200],
                    child: Center(child: Text('Перетащите PDF сюда или вставьте ссылку выше')),
                  ),
                ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
                ElevatedButton(
                  onPressed: () async {
                    if (pdfUrl == null) return;
                    final updated = ServiceRequest(
                      id: req.id,
                      title: req.title,
                      description: req.description,
                      equipmentId: req.equipmentId,
                      userId: req.userId,
                      createdAt: req.createdAt,
                      status: req.status,
                      engineerId: req.engineerId,
                      visitDate: req.visitDate,
                      isArchived: req.isArchived,
                      invoiceUrl: pdfUrl,
                      invoiceAmount: req.invoiceAmount,
                      isPaid: false,
                    );
                    await widget.storageService.updateServiceRequest(updated);
                setState(() {
                      final idx = serviceRequests.indexWhere((r) => r.id == req.id);
                      if (idx != -1) serviceRequests[idx] = updated;
                });
                Navigator.pop(context);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _markRequestPaid(ServiceRequest req) async {
    final updated = ServiceRequest(
      id: req.id,
      title: req.title,
      description: req.description,
      equipmentId: req.equipmentId,
      userId: req.userId,
      createdAt: req.createdAt,
      status: req.status,
      engineerId: req.engineerId,
      visitDate: req.visitDate,
      isArchived: req.isArchived,
      invoiceUrl: req.invoiceUrl,
      invoiceAmount: req.invoiceAmount,
      isPaid: true,
    );
    await widget.storageService.updateServiceRequest(updated);
    setState(() {
      final idx = serviceRequests.indexWhere((r) => r.id == req.id);
      if (idx != -1) serviceRequests[idx] = updated;
    });
  }

  Widget _buildStatistics() {
    final total = serviceRequests.fold<double>(0, (sum, r) => sum + (r.invoiceAmount ?? 0));
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Статистика по затратам', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('Всего заявок: ${serviceRequests.length}'),
          const SizedBox(height: 8),
          Text('Общая сумма: ${total.toStringAsFixed(2)} ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
          const Icon(Icons.person, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
          Text('${widget.user.lastName} ${widget.user.firstName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.user.email, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(widget.user.companyName, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(widget.user.position, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          if (widget.adminUser != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Вернуться в админку'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
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
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
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

  void _showEquipmentCard(Equipment equipment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Image.asset(
                'assets/images/equipment/${equipment.title.split(' ').first}.png',
                      width: 40,
                      height: 40,
                errorBuilder: (c, o, s) => const Icon(Icons.precision_manufacturing),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(equipment.title)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text('Производитель: ${equipment.description}'),
                const SizedBox(height: 8),
                Text('Адрес: ${equipment.address}'),
                const SizedBox(height: 8),
                Text('Контактное лицо: ${equipment.contactName}'),
                const SizedBox(height: 8),
                Text('Телефон: ${equipment.contactPhone}'),
                if (equipment.contactEmail != null && equipment.contactEmail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Email: ${equipment.contactEmail}'),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showServiceRequestDialog(equipment);
                      },
                      child: const Text('Сервис'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showSparePartsDialog(equipment);
                      },
                      child: const Text('Запчасти'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Открыть инструкцию по эксплуатации
                        final manualPath = 'assets/manuals/${equipment.title.split(' ').first}.pdf';
                        // Можно использовать любой PDF viewer или url_launcher
                        // Например: launch(manualPath);
                      },
                      child: const Text('Инструкция'),
                    ),
                  ],
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
        );
      },
    );
  }

  void _showServiceRequestDialog(Equipment e) {}
  void _showSparePartsDialog(Equipment e) {}
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
      final storageService = StorageService(Supabase.instance.client);
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
      final storageService = StorageService(Supabase.instance.client);
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
        children: [
                PopupMenuButton<UserRole>(
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
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onImpersonate(user);
                  },
                  child: const Text('Войти как'),
                ),
              ],
                                  ),
                                );
                              },
      ),
    );
  }
}