import 'package:flutter/material.dart';
import '../services/telegram_bot_service.dart';

class TelegramBotTestScreen extends StatefulWidget {
  const TelegramBotTestScreen({super.key});

  @override
  State<TelegramBotTestScreen> createState() => _TelegramBotTestScreenState();
}

class _TelegramBotTestScreenState extends State<TelegramBotTestScreen> {
  final _phoneController = TextEditingController();
  final _testMessageController = TextEditingController();
  
  bool _isLoading = false;
  bool _botStatus = false;
  Map<String, dynamic>? _botInfo;

  @override
  void initState() {
    super.initState();
    _checkBotStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _testMessageController.dispose();
    super.dispose();
  }

  Future<void> _checkBotStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final status = await TelegramBotService.checkBotStatus();
      final info = await TelegramBotService.getBotInfo();
      
      setState(() {
        _botStatus = status;
        _botInfo = info;
      });
    } catch (e) {
      print('Error checking bot status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestMessage() async {
    if (_phoneController.text.isEmpty || _testMessageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await TelegramBotService.sendRecoveryCode(
        phoneNumber: _phoneController.text,
        recoveryCode: '123456',
        userName: 'Тестовый пользователь',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Тестовое сообщение отправлено!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Не удалось отправить сообщение'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест Telegram бота'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Статус бота
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _botStatus ? Icons.check_circle : Icons.error,
                          color: _botStatus ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Статус бота: ${_botStatus ? "Подключен" : "Не подключен"}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_botInfo != null) ...[
                      const SizedBox(height: 16),
                      Text('Имя бота: ${_botInfo!['first_name']}'),
                      Text('Username: @${_botInfo!['username']}'),
                      Text('ID: ${_botInfo!['id']}'),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _checkBotStatus,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Обновить статус'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Тест отправки сообщения
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Тест отправки сообщения',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Номер телефона',
                        hintText: '+7 (999) 123-45-67',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _testMessageController,
                      decoration: const InputDecoration(
                        labelText: 'Тестовое сообщение',
                        hintText: 'Введите тестовое сообщение',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendTestMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Отправить тестовое сообщение'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Инструкции
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Инструкции по настройке',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('1. Убедитесь, что бот активен в Telegram'),
                    const Text('2. Пользователь должен написать боту /start'),
                    const Text('3. Пользователь должен отправить свой номер телефона'),
                    const Text('4. После этого можно отправлять коды восстановления'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: const Text(
                        'Примечание: Для тестирования пользователь должен сначала написать боту в Telegram, иначе сообщения не дойдут.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
