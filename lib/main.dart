import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;
import 'models/equipment.dart';
import 'models/user.dart';
import 'models/service_request.dart';
import 'services/telegram_webapp_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Инициализируем Telegram WebApp
    TelegramWebAppService.init();

    return MaterialApp(
      title: 'T-Company Service',
      theme: TelegramWebAppService.getTheme(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final User? user;
  final List<ServiceRequest> requests;

  const MyHomePage({
    super.key,
    this.user,
    this.requests = const [],
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('T-Company Service'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => TelegramWebAppService.close(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildEquipmentList(),
          _buildRequestsList(),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.print),
            label: 'Оборудование',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment),
            label: 'Мои заявки',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentList() {
    final user = widget.user;
    final equipmentList = (user != null && user is User) ? user.equipment : <Equipment>[];
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 16),
          itemCount: equipmentList.length,
          itemBuilder: (context, index) {
            final eq = equipmentList[index];
            final imgPath = 'assets/images/equipment/${eq.manufacturer.toLowerCase()}/${eq.model}.PNG';
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EquipmentDetailPage(equipment: eq),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        imgPath,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 54,
                          height: 54,
                          color: Colors.grey[200],
                          child: const Icon(Icons.precision_manufacturing, size: 36, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${eq.manufacturer} ${eq.model}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            eq.serialNumber,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            eq.address,
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton(
            heroTag: 'add_equipment',
            backgroundColor: Colors.blue,
            onPressed: _showAddEquipmentDialog,
            child: const Icon(Icons.add, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    return Center(
      child: Text('Мои заявки'),
    );
  }

  Widget _buildProfile() {
    final user = widget.user ?? TelegramWebAppService.user;
    if (user == null) {
      return const Center(
        child: Text('Пользователь не авторизован'),
      );
    }

    if (user is User) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Text('Компания: ${user.companyName}'),
            Text('ИНН: ${user.inn}'),
          ],
        ),
      );
    } else if (user is Map<String, String>) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Имя: ${user['first_name'] ?? ''}'),
            if (user['last_name'] != null)
              Text('Фамилия: ${user['last_name']}'),
            if (user['username'] != null)
              Text('Username: @${user['username']}'),
          ],
        ),
      );
    }

    return const Center(
      child: Text('Неизвестный тип пользователя'),
    );
  }

  void _showAddEquipmentDialog() {
    final manufacturers = {
      'Tennant': ['T1', 'T2', 'T3', 'T5', 'T500', 'T7', 'T12', 'T15', 'T16', 'M17', 'T20', 'M20'],
      'Gadlee': ['GT 30', 'GT 50 с 50 (сетевая)', 'GT 50 B50 (АКБ)', 'GT 55 BT50', 'GT 70', 'GT 110', 'GT 180 (75 RS)', 'GT 180(B 95)', 'GT 260', 'GTS 920', 'GTS 1200', 'GTS 1450', 'GTS1900'],
      'IPC': ['CT15B35', 'CT15C35', 'CT40B50', 'CT40 BT 50', 'CT40C50', 'CT45B50', 'CT51', 'CT71', 'CT80', 'CT90', 'CT110'],
      'T-line': ['TLO1500', 'T-Mop', 'T-vac'],
      'Gausium': ['ALLYBOT-C2','ECOBOT Phantas', 'ECOBOT Beetle', 'ECOBOT Omnie','ECOBOT Scrubber 50 Pro', 'ECOBOT Scrubber 75', 'ECOBOT Scrubber 50', 'ECOBOT Vacuum 40 Diffuser'],
    };

    String? selectedManufacturer;
    String? selectedModel;
    final serialController = TextEditingController();
    final addressController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    bool showEmail = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Добавить оборудование', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedManufacturer,
                    decoration: const InputDecoration(labelText: 'Производитель'),
                    items: manufacturers.keys
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedManufacturer = value;
                        selectedModel = null;
                      });
                    },
                  ),
                  if (selectedManufacturer != null)
                    DropdownButtonFormField<String>(
                      value: selectedModel,
                      decoration: const InputDecoration(labelText: 'Модель'),
                      items: manufacturers[selectedManufacturer]!
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedModel = value;
                        });
                      },
                    ),
                  TextField(
                    controller: serialController,
                    decoration: const InputDecoration(labelText: 'Серийный номер'),
                  ),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Адрес'),
                  ),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Контактное лицо'),
                  ),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Телефон'),
                    keyboardType: TextInputType.phone,
                  ),
                  if (showEmail)
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => showEmail = !showEmail),
                      child: Text(showEmail ? 'Убрать email' : 'Добавить email'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedManufacturer == null ||
                          selectedModel == null ||
                          serialController.text.isEmpty ||
                          addressController.text.isEmpty ||
                          contactController.text.isEmpty ||
                          phoneController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Заполните все поля!')),
                        );
                        return;
                      }
                      final newEquipment = Equipment(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        manufacturer: selectedManufacturer!,
                        model: selectedModel!,
                        serialNumber: serialController.text,
                        address: addressController.text,
                        contactPerson: contactController.text,
                        phone: phoneController.text,
                        status: 'Работает',
                        ownership: 'В собственности',
                        lastMaintenance: DateTime.now().subtract(const Duration(days: 30)),
                        nextMaintenance: DateTime.now().add(const Duration(days: 30)),
                      );
                      Navigator.pop(context);
                      _addEquipment(newEquipment);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Добавить'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _addEquipment(Equipment equipment) {
    setState(() {
      if (widget.user is User) {
        (widget.user as User).equipment.add(equipment);
      }
    });
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _innController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Временное хранилище пользователей (в реальном приложении это будет база данных)
  static final Map<String, User> _users = {
    '1234567890': User(
      inn: '1234567890',
      companyName: 'T-company',
      password: 'test123',
      equipment: [],
    ),
  };

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      // Имитация задержки сети
      Future.delayed(const Duration(seconds: 1), () {
        final user = _users[_innController.text];
        
        if (user != null && user.password == _passwordController.text) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MyHomePage(user: user, requests: []),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Неверный ИНН или пароль'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.business,
                            size: 48,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'T-Company Service',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Вход в систему',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _innController,
                          decoration: InputDecoration(
                            labelText: 'ИНН',
                            prefixIcon: const Icon(Icons.numbers),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите ИНН';
                            }
                            if (value.length != 10 && value.length != 12) {
                              return 'ИНН должен содержать 10 или 12 цифр';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите пароль';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Войти',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SparePartsPage extends StatelessWidget {
  const SparePartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Контакты менеджера по сервису:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Басалыгин Михаил Сергеевич'),
          Text('Mob: +79817467395'),
          Text('Mail: m.basalygin@t-co.ru'),
        ],
      ),
    );
  }
}

class ServiceRequestPage extends StatelessWidget {
  final List<ServiceRequest> requests;
  const ServiceRequestPage({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      body: requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Нет заявок',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[requests.length - 1 - index]; // новые сверху
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: req.type == 'Запчасти' 
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          req.type == 'Запчасти' 
                              ? Icons.build
                              : Icons.engineering,
                          color: req.type == 'Запчасти' 
                              ? Colors.orange
                              : Colors.blue,
                          size: 24,
                        ),
                      ),
                    ),
                    title: Text('${req.type} — ${req.equipmentTitle}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Дата: ${req.date.toString().split(' ')[0]}'),
                        Text('Сообщение: ${req.message}'),
                        Text('Статус: ${req.status}'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ServiceRequest {
  final String id;
  final String equipmentTitle;
  final String type; // 'Запчасти' или 'Инженер'
  final String message;
  final DateTime date;
  String status; // 'Отправлено', 'В обработке', 'Завершено'

  ServiceRequest({
    required this.id,
    required this.equipmentTitle,
    required this.type,
    required this.message,
    required this.date,
    this.status = 'Отправлено',
  });
}

class StatisticsPage extends StatefulWidget {
  final List<Equipment> equipment;
  final List<ServiceRequest> requests;

  const StatisticsPage({
    super.key,
    required this.equipment,
    required this.requests,
  });

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedPeriod = 'Месяц';
  String? _selectedEquipment;

  List<String> get _periods => ['Неделя', 'Месяц', 'Квартал', 'Год'];

  Map<String, double> _getExpensesByType() {
    final expenses = <String, double>{
      'Запчасти': 0,
      'Услуги': 0,
    };

    for (final request in widget.requests) {
      if (request.status == 'Завершено') {
        final amount = request.type == 'Запчасти' ? 5000.0 : 8000.0;
        expenses[request.type] = (expenses[request.type] ?? 0) + amount;
      }
    }

    return expenses;
  }

  Map<String, double> _getExpensesByEquipment() {
    final expenses = <String, double>{};

    for (final equip in widget.equipment) {
      expenses[equip.model] = 0;
    }

    for (final request in widget.requests) {
      if (request.status == 'Завершено') {
        final amount = request.type == 'Запчасти' ? 5000.0 : 8000.0;
        expenses[request.equipmentTitle] = (expenses[request.equipmentTitle] ?? 0) + amount;
      }
    }

    return expenses;
  }

  @override
  Widget build(BuildContext context) {
    final expensesByType = _getExpensesByType();
    final expensesByEquipment = _getExpensesByEquipment();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Период',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: _periods.map((period) {
                      return ButtonSegment<String>(
                        value: period,
                        label: Text(period),
                      );
                    }).toList(),
                    selected: {_selectedPeriod},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedPeriod = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Расходы по типам',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: expensesByType.entries.map((entry) {
                          return PieChartSectionData(
                            value: entry.value,
                            title: '${entry.key}\n${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(entry.value)}',
                            color: entry.key == 'Запчасти' ? Colors.orange : Colors.blue,
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Расходы по оборудованию',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: expensesByEquipment.values.isEmpty ? 0 : expensesByEquipment.values.reduce(math.max) * 1.2,
                        barGroups: expensesByEquipment.entries.map((entry) {
                          return BarChartGroupData(
                            x: expensesByEquipment.keys.toList().indexOf(entry.key),
                            barRods: [
                              BarChartRodData(
                                toY: entry.value,
                                color: Colors.blue,
                                width: 20,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final model = expensesByEquipment.keys.elementAt(value.toInt());
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    model,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  NumberFormat.compact(locale: 'ru_RU').format(value),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Календарь обслуживания',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TableCalendar(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2025, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    eventLoader: (day) {
                      return widget.requests.where((request) {
                        return isSameDay(request.date, day);
                      }).toList();
                    },
                    calendarStyle: const CalendarStyle(
                      markersMaxCount: 1,
                      markerDecoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceRequest {
  final DateTime date;
  final String equipmentName;
  final String description;

  MaintenanceRequest({
    required this.date,
    required this.equipmentName,
    required this.description,
  });
}

List<DropdownMenuItem<String>> _getModelsForManufacturer(String manufacturer) {
  final models = {
    'Gadlee': ['GT55', 'GT70', 'GT110'],
    'Gausium': ['Scrubber 50', 'Vacuum 40'],
    'T-line': ['T1', 'T2', 'T3-43M'],
    'IPC': ['CT15B35', 'CT15C35', 'CT40B50'],
    'Tennant': ['T300', 'T500', '5680'],
  };
  return (models[manufacturer] ?? [])
      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
      .toList();
}

class EquipmentDetailPage extends StatelessWidget {
  final Equipment equipment;
  const EquipmentDetailPage({super.key, required this.equipment});

  @override
  Widget build(BuildContext context) {
    final manualPath = 'assets/manuals/${equipment.model}.pdf';
    return Scaffold(
      appBar: AppBar(
        title: Text('${equipment.model} — ${equipment.serialNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Редактировать',
            onPressed: () {
              // TODO: реализовать редактирование
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/equipment/${equipment.manufacturer.toLowerCase()}/${equipment.model}.PNG',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.precision_manufacturing, size: 60),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(equipment.manufacturer, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(equipment.model, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Серийный номер: ${equipment.serialNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(equipment.address, style: const TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Контактное лицо'),
              subtitle: Text(equipment.contactPerson),
              trailing: Icon(Icons.phone, color: Colors.blue.shade700),
              onTap: () {
                // TODO: реализовать звонок
              },
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Телефон'),
              subtitle: Text(equipment.phone),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Гарантия'),
              subtitle: Text('Информация о гарантии (не редактируется)'),
            ),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Техническое обслуживание'),
            children: [
              ListTile(
                title: const Text('Последнее ТО'),
                subtitle: Text('${equipment.lastMaintenance.toLocal()}'),
              ),
              ListTile(
                title: const Text('Следующее ТО'),
                subtitle: Text('${equipment.nextMaintenance.toLocal()}'),
              ),
              // TODO: добавить таблицу прошлых и будущих ТО
            ],
          ),
          ExpansionTile(
            title: const Text('Инструкция по эксплуатации (PDF)'),
            children: [
              ListTile(
                title: const Text('Открыть инструкцию'),
                onTap: () {
                  // TODO: реализовать открытие PDF
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.engineering),
                label: const Text('Сервис'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Вызов инженера'),
                      content: TextFormField(
                        decoration: const InputDecoration(labelText: 'Опишите проблему'),
                        maxLines: 3,
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отправить'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.build),
                label: const Text('Запчасти'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Заказ запчастей'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            items: [
                              DropdownMenuItem(value: 'part1', child: Text('Запчасть 1')),
                              DropdownMenuItem(value: 'part2', child: Text('Запчасть 2')),
                            ],
                            onChanged: (_) {},
                            decoration: const InputDecoration(labelText: 'Выберите запчасть'),
                          ),
                          TextFormField(
                            decoration: const InputDecoration(labelText: 'Описание/комментарий'),
                            maxLines: 2,
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отправить'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}