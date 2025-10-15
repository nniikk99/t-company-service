import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/supabase_service.dart';
import '../models/equipment.dart';

class SupabaseTestScreen extends StatefulWidget {
  const SupabaseTestScreen({super.key});

  @override
  State<SupabaseTestScreen> createState() => _SupabaseTestScreenState();
}

class _SupabaseTestScreenState extends State<SupabaseTestScreen> {
  String _connectionStatus = 'Проверка подключения...';
  bool _isLoading = true;
  List<Map<String, dynamic>> _companies = [];
  String _equipmentTestStatus = 'Не протестировано';
  bool _equipmentTestLoading = false;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Тест 1: Проверяем подключение
      setState(() {
        _connectionStatus = 'Подключение к Supabase...';
      });

      // Тест 2: Простой запрос к auth (должен всегда работать)
      final user = supabase.auth.currentUser;
      setState(() {
        _connectionStatus = 'Подключение установлено. Пользователь: ${user?.email ?? "не авторизован"}';
      });

      // Тест 3: Попробуем получить данные из companies (нужно создать таблицу)
      try {
        final response = await supabase
            .from('companies')
            .select('*')
            .limit(5);
        
        setState(() {
          _companies = List<Map<String, dynamic>>.from(response);
          _connectionStatus = 'Подключение успешно! Найдено компаний: ${_companies.length}';
        });
      } catch (e) {
        setState(() {
          _connectionStatus = 'Подключение установлено, но таблица companies не найдена: $e';
        });
      }

    } catch (e) {
      setState(() {
        _connectionStatus = 'Ошибка подключения: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createTestCompany() async {
    try {
      setState(() {
        _isLoading = true;
        _connectionStatus = 'Создание тестовой компании...';
      });

      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('companies')
          .insert({
            'name': 'Тестовая компания ${DateTime.now().millisecondsSinceEpoch}',
            'description': 'Создана из Flutter приложения',
            'contact_email': 'test@example.com',
          })
          .select()
          .single();

      setState(() {
        _connectionStatus = 'Тестовая компания создана: ${response['name']}';
      });

      // Обновляем список
      _testConnection();

    } catch (e) {
      setState(() {
        _connectionStatus = 'Ошибка создания компании: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testEquipmentCreation() async {
    try {
      setState(() {
        _equipmentTestLoading = true;
        _equipmentTestStatus = 'Создание тестового оборудования...';
      });

      // Сначала получим первую доступную компанию
      final supabase = Supabase.instance.client;
      final companiesResponse = await supabase
          .from('companies')
          .select('id')
          .limit(1);

      if (companiesResponse.isEmpty) {
        setState(() {
          _equipmentTestStatus = 'Ошибка: нет компаний для теста. Создайте компанию сначала.';
          _equipmentTestLoading = false;
        });
        return;
      }

      final companyId = companiesResponse.first['id'];

      // Создаем тестовое оборудование
      final testEquipment = Equipment(
        id: const Uuid().v4(),
        clientId: companyId,
        companyId: companyId,
        name: 'Тестовая машина',
        manufacturer: 'Gadlee',
        model: 'GT30',
        modification: 'Тест',
        serialNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        location: 'Тестовая площадка',
        address: 'Тестовый адрес',
        status: EquipmentStatus.active,
        description: 'Создано для тестирования сохранения в Supabase',
        createdAt: DateTime.now(),
      );

      // Используем SupabaseService для создания
      final savedEquipment = await SupabaseService.createEquipment(testEquipment);

      setState(() {
        _equipmentTestStatus = '✅ Оборудование успешно создано!\nID: ${savedEquipment.id}\nНазвание: ${savedEquipment.name}';
        _equipmentTestLoading = false;
      });

    } catch (e) {
      setState(() {
        _equipmentTestStatus = '❌ Ошибка создания оборудования: $e';
        _equipmentTestLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест Supabase подключения'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
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
                    Text(
                      'Статус подключения:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Проверка...'),
                        ],
                      )
                    else
                      Text(
                        _connectionStatus,
                        style: TextStyle(
                          color: _connectionStatus.contains('успешно') 
                              ? Colors.green[700]
                              : _connectionStatus.contains('Ошибка')
                                  ? Colors.red[700]
                                  : Colors.orange[700],
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
                    Text(
                      'Тест создания оборудования:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_equipmentTestLoading)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Тестирование...'),
                        ],
                      )
                    else
                      Text(
                        _equipmentTestStatus,
                        style: TextStyle(
                          color: _equipmentTestStatus.contains('✅') 
                              ? Colors.green[700]
                              : _equipmentTestStatus.contains('❌')
                                  ? Colors.red[700]
                                  : Colors.grey[700],
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _equipmentTestLoading ? null : _testEquipmentCreation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Тест создания оборудования'),
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
                    Text(
                      'Информация о проекте:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('URL: https://kwunhuzfnjpcoeusnxzy.supabase.co'),
                    const SizedBox(height: 4),
                    Text('Ключ: eyJhbGciOiJIUzI1NiIsInR5cCI6...'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_companies.isNotEmpty) ...[
              Text(
                'Компании в базе данных:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _companies.length,
                  itemBuilder: (context, index) {
                    final company = _companies[index];
                    return Card(
                      child: ListTile(
                        title: Text(company['name'] ?? 'Без названия'),
                        subtitle: Text(company['description'] ?? 'Без описания'),
                        trailing: Text(
                          company['created_at']?.substring(0, 10) ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testConnection,
                  child: const Text('Проверить снова'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createTestCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Создать тестовую компанию'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
