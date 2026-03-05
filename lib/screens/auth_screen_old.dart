import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/telegram_webapp_service.dart';
import '../services/storage_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  bool _consentGiven = false;
  String? _telegramUser;

  @override
  void initState() {
    super.initState();
    _checkTelegramAuth();
  }

  Future<void> _checkTelegramAuth() async {
    setState(() => _isLoading = true);

    try {
      final telegramUser = await TelegramWebAppService.getUser();
      if (telegramUser != null) {
        setState(() {
          _telegramUser = telegramUser['first_name'];
        });
      }
    } catch (e) {
      print('Telegram auth error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticate() async {
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Необходимо дать согласие на обработку персональных данных')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Имитация авторизации через Telegram
      await Future.delayed(const Duration(seconds: 2));

      // Сохраняем данные пользователя
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', 'demo_user_1');
      await prefs.setString('user_role', 'clientManager');
      await prefs.setString('client_id', '00000000-0000-0000-0000-000000000001');
      await prefs.setBool('is_logged_in', true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Авторизация успешна!'),
          backgroundColor: Colors.green,
        ),
      );

      // Получаем пользователя и переходим к dashboard
      final users = await StorageService.getUsers();
      final user = users.firstWhere(
        (u) => u.id == 'demo_user_1',
        orElse: () => users.first,
      );
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard', arguments: user);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Логотип
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.build,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),

              // Заголовок
              const Text(
                'Сервисная служба',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Подзаголовок
              Text(
                _telegramUser != null
                  ? 'Добро пожаловать, $_telegramUser!'
                  : 'T-Company Service',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),

              // Согласие на обработку ПД
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _consentGiven,
                            onChanged: (value) {
                              setState(() {
                                _consentGiven = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Согласие на обработку персональных данных',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _authenticate,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Войти через Telegram'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isLoading ? null : () => _authenticate(),
                        child: const Text('Демо-вход'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
