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
import 'package:supabase_flutter/supabase_flutter.dart';

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
      home: const AuthPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final User user;
  final List<ServiceRequest> requests;

  const MyHomePage({
    super.key,
    required this.user,
    this.requests = const [],
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  late List<Equipment> _equipmentList;
  late Map<String, User> _allUsers;
  List<ServiceRequest> serviceRequests = [];

  @override
  void initState() {
    super.initState();
    _equipmentList = List<Equipment>.from(widget.user.equipment);
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    _allUsers = await StorageService.loadUsers();
  }

  String _formatPhoneNumber(String value) {
    // Убираем все символы кроме цифр
    String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Ограничиваем до 10 цифр (после +7)
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    
    // Форматируем номер
    if (digits.length <= 3) {
      return digits;
    } else if (digits.length <= 6) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    } else if (digits.length <= 8) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)}-${digits.substring(6, 8)}-${digits.substring(8)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('T-Company Service'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
          StatisticsPage(equipment: _equipmentList, requests: serviceRequests),
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
            icon: ImageIcon(AssetImage('assets/icons/equipment.png')),
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.precision_manufacturing, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Оборудование (${_equipmentList.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Equipment List
          Expanded(
            child: _equipmentList.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.precision_manufacturing, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет оборудования', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text('Нажмите + чтобы добавить', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _equipmentList.length,
                    itemBuilder: (context, index) {
                      final equipment = _equipmentList[index];
                      return _buildEquipmentCard(equipment);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEquipmentDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEquipmentCard(Equipment equipment) {
    // Исправляем путь к изображению - убираем пробелы и специальные символы
    String cleanModel = equipment.model
        .replaceAll(' ', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('-', '');
    
    final imgPath = 'assets/images/equipment/${equipment.manufacturer.toLowerCase()}/$cleanModel.PNG';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final updatedEquipment = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EquipmentDetailPage(equipment: equipment, user: widget.user, onAddRequest: _addServiceRequest),
            ),
          );
          
          // Обрабатываем результат
          if (updatedEquipment != null) {
            if (updatedEquipment == 'DELETE') {
              // Удаляем оборудование
              _deleteEquipment(equipment);
            } else if (updatedEquipment is Equipment) {
              // Обновляем оборудование
              _updateEquipment(equipment, updatedEquipment);
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar/Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.blue[50],
                  child: Image.asset(
                    imgPath,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ Не найдено изображение: $imgPath');
                      return const Icon(
                        Icons.precision_manufacturing,
                        color: Colors.blue,
                        size: 28,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      '${equipment.manufacturer} ${equipment.model}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Subtitle
                    Text(
                      'S/N: ${equipment.serialNumber}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Address
                    Text(
                      equipment.address,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEquipmentDialog() {
    final manufacturers = {
      'Tennant': ['T2', 'T7', 'T12', 'T16', 'T17', 'T20', 'T300', 'T500', 'M17', 'M20', 'M30', 'S30'],
      'Gadlee': ['GT30', 'GT50', 'GT55', 'GT70', 'GT85', 'GT110', 'GT180(75RS)', 'GT180 B95', 'GTS920', 'GTS 1200', 'GTS1450', 'GTS 1900'],
      'IPC': ['CT30', 'CT51 BТ55', 'CT70 BТ55', 'CT45 B50'],
      'T-line': ['TLO-1500', 'T-mop', 'T-line'],
      'Gausium': ['Beetle', 'Omnie', 'Phantas', 'Scrubber 50 Pro', 'Scrubber 50', 'Scrubber 75', 'Vacuum 40'],
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
            builder: (context, setModalState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Добавить оборудование',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Производитель
                  DropdownButtonFormField<String>(
                    value: selectedManufacturer,
                    decoration: InputDecoration(
                      labelText: 'Производитель *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: manufacturers.keys
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedManufacturer = value;
                        selectedModel = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Модель
                  if (selectedManufacturer != null)
                    DropdownButtonFormField<String>(
                      value: selectedModel,
                      decoration: InputDecoration(
                        labelText: 'Модель *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: manufacturers[selectedManufacturer]!
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedModel = value;
                        });
                      },
                    ),
                  if (selectedManufacturer != null) const SizedBox(height: 16),
                  
                  // Серийный номер
                  TextField(
                    controller: serialController,
                    decoration: InputDecoration(
                      labelText: 'Серийный номер *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Адрес
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Адрес *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Контактное лицо
                  TextField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: 'Контактное лицо *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Телефон
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Телефон *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixText: '+7 ',
                      hintText: '999 123-45-67',
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) {
                      // Форматируем номер телефона
                      String formatted = _formatPhoneNumber(value);
                      if (formatted != value) {
                        phoneController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email (опционально)
                  if (showEmail)
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  if (showEmail) const SizedBox(height: 16),
                  
                  // Кнопка добавить email
                  TextButton.icon(
                    onPressed: () => setModalState(() => showEmail = !showEmail),
                    icon: Icon(showEmail ? Icons.remove : Icons.add),
                    label: Text(showEmail ? 'Убрать email' : 'Добавить email'),
                  ),
                  const SizedBox(height: 20),
                  
                  // Кнопка добавить
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Проверка обязательных полей
                        if (selectedManufacturer == null ||
                            selectedModel == null ||
                            serialController.text.trim().isEmpty ||
                            addressController.text.trim().isEmpty ||
                            contactController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Заполните все обязательные поля!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        // Создание нового оборудования
                        final newEquipment = Equipment(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          manufacturer: selectedManufacturer!,
                          model: selectedModel!,
                          serialNumber: serialController.text.trim(),
                          address: addressController.text.trim(),
                          contactPerson: contactController.text.trim(),
                          phone: '+7 ${phoneController.text.trim()}',
                          status: 'Работает',
                          ownership: 'В собственности',
                          lastMaintenance: DateTime.now().subtract(const Duration(days: 30)),
                          nextMaintenance: DateTime.now().add(const Duration(days: 30)),
                        );
                        
                        // Закрыть модальное окно
                        Navigator.pop(context);
                        
                        // Добавить оборудование
                        _addEquipment(newEquipment);
                        
                        // Показать сообщение об успехе
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Оборудование "${newEquipment.manufacturer} ${newEquipment.model}" добавлено!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Добавить', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _addEquipment(Equipment equipment) async {
    setState(() {
      _equipmentList.add(equipment);
      widget.user.equipment.add(equipment);
    });
    
    // Сохраняем данные
    await StorageService.saveUser(widget.user, _allUsers);
    
    print('✅ Оборудование добавлено: ${equipment.manufacturer} ${equipment.model}');
    print('📊 Всего оборудования: ${_equipmentList.length}');
  }

  void _updateEquipment(Equipment oldEquipment, Equipment newEquipment) async {
    setState(() {
      // Находим индекс в локальном списке
      final index = _equipmentList.indexWhere((eq) => eq.id == oldEquipment.id);
      if (index != -1) {
        _equipmentList[index] = newEquipment;
      }
      
      // Находим индекс в списке пользователя
      final userIndex = widget.user.equipment.indexWhere((eq) => eq.id == oldEquipment.id);
      if (userIndex != -1) {
        widget.user.equipment[userIndex] = newEquipment;
      }
    });
    
    // Сохраняем данные
    await StorageService.saveUser(widget.user, _allUsers);
    
    print('✅ Оборудование обновлено: ${newEquipment.manufacturer} ${newEquipment.model}');
  }

  void _deleteEquipment(Equipment equipment) async {
    setState(() {
      // Удаляем из локального списка
      _equipmentList.removeWhere((eq) => eq.id == equipment.id);
      
      // Удаляем из списка пользователя
      widget.user.equipment.removeWhere((eq) => eq.id == equipment.id);
    });
    
    // Сохраняем изменения
    await StorageService.saveUser(widget.user, _allUsers);
    
    print('🗑️ Оборудование удалено: ${equipment.manufacturer} ${equipment.model}');
    print('📊 Осталось оборудования: ${_equipmentList.length}');
  }

  Widget _buildRequestsList() {
    if (serviceRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Мои заявки', style: TextStyle(fontSize: 18)),
            Text('Здесь будут отображаться ваши заявки', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: serviceRequests.length,
      itemBuilder: (context, index) {
        final req = serviceRequests[index];
        return ListTile(
          title: Text(req.equipmentTitle),
          subtitle: Text(req.message),
          // и т.д.
        );
      },
    );
  }

  Widget _buildProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business, size: 80, color: Colors.blue),
          const SizedBox(height: 16),
          Text('Компания: ${widget.user.companyName}', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('ИНН: ${widget.user.inn}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    // Показываем диалог с выбором
    final shouldClearRememberMe = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Забыть данные для автовхода?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет, запомнить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да, забыть'),
          ),
        ],
      ),
    );
    
    await StorageService.clearCurrentUser();
    
    if (shouldClearRememberMe == true) {
      await StorageService.clearRememberMe();
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthPage()),
    );
  }

  void _addServiceRequest(ServiceRequest request) async {
    setState(() {
      serviceRequests.add(request);
    });
    // Если нужно — сохрани в SharedPreferences
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
  bool _rememberMe = true; // По умолчанию включено для удобства
  Map<String, User> _users = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _checkAutoLogin();
  }

  Future<void> _loadUsers() async {
    _users = await StorageService.loadUsers();
    setState(() {});
  }

  Future<void> _checkAutoLogin() async {
    // Сначала проверяем сохраненные данные для автовхода
    final rememberData = await StorageService.loadRememberMe();
    if (rememberData != null) {
      final inn = rememberData['inn']!;
      final password = rememberData['password']!;
      
      if (_users.containsKey(inn)) {
        final user = _users[inn]!;
        if (user.password == password) {
          print('🔐 Автовход по сохраненным данным');
          _navigateToHome(user);
          return;
        }
      }
    }
    
    // Если автовход не сработал, проверяем текущего пользователя
    final currentUserInn = await StorageService.loadCurrentUser();
    if (currentUserInn != null && _users.containsKey(currentUserInn)) {
      final user = _users[currentUserInn]!;
      _navigateToHome(user);
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      await Future.delayed(const Duration(seconds: 1));
      
      final user = _users[_innController.text];
      
      if (user != null && user.password == _passwordController.text) {
        // Сохраняем текущего пользователя
        await StorageService.saveCurrentUser(user.inn);
        
        // Если включено "Запомнить меня", сохраняем данные для автовхода
        if (_rememberMe) {
          await StorageService.saveRememberMe(user.inn, user.password);
        }
        
        _navigateToHome(user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неверный ИНН или пароль'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _navigateToHome(User user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MyHomePage(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade900, Colors.blue.shade700],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          child: const Icon(Icons.business, size: 48, color: Colors.blue),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'T-Company Service',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        const Text('Вход в систему', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _innController,
                          decoration: InputDecoration(
                            labelText: 'ИНН',
                            prefixIcon: const Icon(Icons.numbers),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Пожалуйста, введите ИНН';
                            if (value.length != 10 && value.length != 12) return 'ИНН должен содержать 10 или 12 цифр';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Пожалуйста, введите пароль';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            const Text('Запомнить меня'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Войти', style: TextStyle(fontSize: 16, color: Colors.white)),
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
          Text('Контакты менеджера по сервису:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
  final User user;
  final void Function(ServiceRequest) onAddRequest;

  const EquipmentDetailPage({super.key, required this.equipment, required this.user, required this.onAddRequest});

  String _formatPhoneNumber(String value) {
    // Убираем все символы кроме цифр
    String digits = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Ограничиваем до 10 цифр (после +7)
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    
    // Форматируем номер
    if (digits.length <= 3) {
      return digits;
    } else if (digits.length <= 6) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    } else if (digits.length <= 8) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)}-${digits.substring(6, 8)}-${digits.substring(8)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${equipment.model} — ${equipment.serialNumber}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Редактировать',
            onPressed: () => _showEditEquipmentDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Удалить',
            color: Colors.red,
            onPressed: () => _showDeleteConfirmDialog(context),
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
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.blue[50],
                  child: Image.asset(
                    'assets/images/equipment/${equipment.manufacturer.toLowerCase()}/${equipment.model.replaceAll(' ', '').replaceAll('(', '').replaceAll(')', '').replaceAll('-', '')}.PNG',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.precision_manufacturing, size: 60, color: Colors.blue),
                  ),
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
              trailing: const Icon(Icons.person, color: Colors.blue),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Телефон'),
              subtitle: Text(equipment.phone),
              trailing: GestureDetector(
                onTap: () => _makePhoneCall(context, equipment.phone),
                child: const Icon(Icons.phone, color: Colors.blue),
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Статус'),
              subtitle: Text(equipment.status),
              trailing: Icon(Icons.check_circle, color: equipment.status == 'Работает' ? Colors.green : Colors.orange),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showServiceRequestDialog(context);
                  },
                  icon: const Icon(Icons.build),
                  label: const Text('Сервис'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showPartsRequestDialog(context);
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Запчасти'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Кнопка инструкции
          ElevatedButton.icon(
            onPressed: () {
              final manualUrl = '${Uri.base.origin}/t-company-service/assets/assets/manuals/${equipment.model}.pdf';
              html.window.open(manualUrl, '_blank');
            },
            icon: const Icon(Icons.menu_book),
            label: const Text('Инструкция'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
          FutureBuilder<List<WarrantyInfo>>(
            future: fetchWarrantyData(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              WarrantyInfo? warranty;
              try {
                warranty = snapshot.data!.firstWhere((w) => w.serial == equipment.serialNumber);
              } catch (_) {
                warranty = null;
              }
              if (warranty == null) return SizedBox();
              return Card(
                child: ListTile(
                  title: Text('Гарантия'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Клиент: ${warranty.client}'),
                      Text('Документ: ${warranty.document}'),
                      Text('Срок: ${warranty.warrantyStart} — ${warranty.warrantyEnd}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditEquipmentDialog(BuildContext context) {
    final manufacturers = {
      'Tennant': ['T2', 'T7', 'T12', 'T16', 'T17', 'T20', 'T300', 'T500', 'M17', 'M20', 'M30', 'S30'],
      'Gadlee': ['GT30', 'GT50', 'GT55', 'GT70', 'GT85', 'GT110', 'GT180(75RS)', 'GT180 B95', 'GTS920', 'GTS 1200', 'GTS1450', 'GTS 1900'],
      'IPC': ['CT30', 'CT51 BТ55', 'CT70 BТ55', 'CT45 B50'],
      'T-line': ['TLO-1500', 'T-mop', 'T-line'],
      'Gausium': ['Beetle', 'Omnie', 'Phantas', 'Scrubber 50 Pro', 'Scrubber 50', 'Scrubber 75', 'Vacuum 40'],
    };

    // Предзаполняем поля данными оборудования
    String? selectedManufacturer = equipment.manufacturer;
    String? selectedModel = equipment.model;
    final serialController = TextEditingController(text: equipment.serialNumber);
    final addressController = TextEditingController(text: equipment.address);
    final contactController = TextEditingController(text: equipment.contactPerson);
            final phoneController = TextEditingController(
          text: equipment.phone.startsWith('+7 ') 
              ? equipment.phone.substring(3) 
              : equipment.phone
        );
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
            builder: (context, setModalState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Редактировать оборудование',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Производитель
                  DropdownButtonFormField<String>(
                    value: selectedManufacturer,
                    decoration: InputDecoration(
                      labelText: 'Производитель *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: manufacturers.keys
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedManufacturer = value;
                        if (value != equipment.manufacturer) {
                          selectedModel = null; // Сбрасываем модель если изменился производитель
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Модель
                  if (selectedManufacturer != null)
                    DropdownButtonFormField<String>(
                      value: selectedModel,
                      decoration: InputDecoration(
                        labelText: 'Модель *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: manufacturers[selectedManufacturer]!
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedModel = value;
                        });
                      },
                    ),
                  if (selectedManufacturer != null) const SizedBox(height: 16),
                  
                  // Серийный номер
                  TextField(
                    controller: serialController,
                    decoration: InputDecoration(
                      labelText: 'Серийный номер *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Адрес
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Адрес *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Контактное лицо
                  TextField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: 'Контактное лицо *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Телефон
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Телефон *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixText: '+7 ',
                      hintText: '999 123-45-67',
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) {
                      // Форматируем номер телефона
                      String formatted = _formatPhoneNumber(value);
                      if (formatted != value) {
                        phoneController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email (опционально)
                  if (showEmail)
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  if (showEmail) const SizedBox(height: 16),
                  
                  // Кнопка добавить email
                  TextButton.icon(
                    onPressed: () => setModalState(() => showEmail = !showEmail),
                    icon: Icon(showEmail ? Icons.remove : Icons.add),
                    label: Text(showEmail ? 'Убрать email' : 'Добавить email'),
                  ),
                  const SizedBox(height: 20),
                  
                  // Кнопки
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Проверка обязательных полей
                            if (selectedManufacturer == null ||
                                selectedModel == null ||
                                serialController.text.trim().isEmpty ||
                                addressController.text.trim().isEmpty ||
                                contactController.text.trim().isEmpty ||
                                phoneController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Заполните все обязательные поля!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            // Создаем обновленное оборудование
                            final updatedEquipment = equipment.copyWith(
                              manufacturer: selectedManufacturer!,
                              model: selectedModel!,
                              serialNumber: serialController.text.trim(),
                              address: addressController.text.trim(),
                              contactPerson: contactController.text.trim(),
                              phone: '+7 ${phoneController.text.trim()}',
                            );
                            
                            // Закрыть модальное окно
                            Navigator.pop(context);
                            
                            // Закрыть страницу деталей и вернуть обновленные данные
                            Navigator.pop(context, updatedEquipment);
                            
                            // Показать сообщение об успехе
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Оборудование "${updatedEquipment.manufacturer} ${updatedEquipment.model}" обновлено!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _makePhoneCall(BuildContext context, String phoneNumber) async {
    // Очищаем номер от всех символов кроме цифр
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
    
    try {
      // В веб-версии показываем диалог с возможностью копирования
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Позвонить'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              SelectableText(
                phoneNumber,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Нажмите "Позвонить" чтобы начать звонок',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Открываем звонок в новом окне
                html.window.open(phoneUri.toString(), '_blank');
                Navigator.pop(context);
              },
              icon: const Icon(Icons.phone),
              label: const Text('Позвонить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось совершить звонок: $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              const Text('Удалить оборудование?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вы действительно хотите удалить это оборудование?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${equipment.manufacturer} ${equipment.model}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('S/N: ${equipment.serialNumber}'),
                    Text('Адрес: ${equipment.address}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Это действие нельзя отменить!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Закрыть диалог
                Navigator.pop(context, 'DELETE'); // Вернуться на главную с сигналом удаления
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Оборудование "${equipment.manufacturer} ${equipment.model}" удалено'),
                    backgroundColor: Colors.red,
                    action: SnackBarAction(
                      label: 'Отменить',
                      textColor: Colors.white,
                      onPressed: () {
                        // TODO: Можно добавить функцию восстановления
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }

  void _showServiceRequestDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Заявка на сервис'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Опишите проблему',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final problem = controller.text.trim();
              if (problem.isNotEmpty) {
                final newRequest = ServiceRequest(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  equipmentTitle: '${user.companyName} - ${equipment.model}',
                  type: 'Инженер',
                  message: problem,
                  date: DateTime.now(),
                  status: 'Отправлено',
                );
                onAddRequest(newRequest);
                Navigator.pop(context);
              }
            },
            child: Text('Отправить'),
          ),
        ],
      ),
    );
  }

  void _showPartsRequestDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Заявка на запчасти'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Какие запчасти нужны?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final parts = controller.text.trim();
              if (parts.isNotEmpty) {
                final newRequest = ServiceRequest(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  equipmentTitle: '${user.companyName} - ${equipment.model}',
                  type: 'Запчасти',
                  message: parts,
                  date: DateTime.now(),
                  status: 'Отправлено',
                );
                onAddRequest(newRequest);
                Navigator.pop(context);
              }
            },
            child: Text('Отправить'),
          ),
        ],
      ),
    );
  }
}

// Модель гарантии
class WarrantyInfo {
  final String serial;
  final String document;
  final String client;
  final String warrantyStart;
  final String warrantyEnd;

  WarrantyInfo({
    required this.serial,
    required this.document,
    required this.client,
    required this.warrantyStart,
    required this.warrantyEnd,
  });

  factory WarrantyInfo.fromJson(Map<String, dynamic> json) => WarrantyInfo(
    serial: json['Серийный номер'] ?? '',
    document: json['Документ'] ?? '',
    client: json['Клиент'] ?? '',
    warrantyStart: json['Дата начала гарантии'] ?? '',
    warrantyEnd: json['Дата окончания гарантии'] ?? '',
  );
}

// Получение данных из Google Sheets
Future<List<WarrantyInfo>> fetchWarrantyData() async {
  final url = 'https://opensheet.elk.sh/1e2m9SXC9-sVQWtYcdKwU9ONBMgeK9N8d/Лист_1';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
    return data.map((e) => WarrantyInfo.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load warranty data');
  }
}