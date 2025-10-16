import 'package:flutter/material.dart';
import '../services/password_service.dart';
import '../services/telegram_bot_service.dart';
import '../services/supabase_service.dart';
import '../models/user.dart' as AppUserModel;
import '../widgets/error_dialog.dart';
import '../widgets/phone_input_field.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _recoveryCode;
  AppUserModel.User? _user;
  int _attemptsLeft = 3;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendRecoveryCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Ищем пользователя по номеру телефона
      final users = await SupabaseService.getUsers();
      final normalizedPhone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      
      _user = users.firstWhere(
        (u) => u.phone.replaceAll(RegExp(r'[^\d]'), '') == normalizedPhone,
        orElse: () => throw Exception('Пользователь не найден'),
      );

      // Генерируем код восстановления
      _recoveryCode = PasswordService.generateRecoveryCode();

      // Отправляем код через Telegram бот
      final success = await TelegramBotService.sendRecoveryCode(
        phoneNumber: _user!.phone,
        recoveryCode: _recoveryCode!,
        userName: '${_user!.firstName} ${_user!.lastName}',
      );

      if (success) {
        setState(() => _codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Код восстановления отправлен в Telegram!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Если не удалось отправить через бота, показываем инструкции
        _showBotInstructionsDialog();
      }
    } catch (e) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка восстановления',
        message: 'Не удалось найти пользователя с указанным номером телефона или отправить код восстановления.\n\nПроверьте правильность номера телефона.',
        onRetry: () {
          _phoneController.clear();
        },
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCodeAndResetPassword() async {
    if (_codeController.text.trim() != _recoveryCode) {
      setState(() => _attemptsLeft--);
      
      if (_attemptsLeft <= 0) {
        ErrorDialog.show(
          context: context,
          title: 'Превышено количество попыток',
          message: 'Вы превысили максимальное количество попыток ввода кода.\n\nПожалуйста, начните процедуру восстановления заново.',
          onRetry: () {
            setState(() {
              _codeSent = false;
              _attemptsLeft = 3;
              _codeController.clear();
            });
          },
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Неверный код. Осталось попыток: $_attemptsLeft'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Генерируем новый пароль
      final newPassword = PasswordService.generateRandomPassword(length: 10);
      final newPasswordHash = PasswordService.hashPassword(newPassword);

      // Обновляем пароль в базе данных
      await SupabaseService.changePassword(_user!.id, newPasswordHash);

      // Отправляем новый пароль через Telegram бот
      final success = await TelegramBotService.sendNewPassword(
        phoneNumber: _user!.phone,
        newPassword: newPassword,
        userName: '${_user!.firstName} ${_user!.lastName}',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Новый пароль отправлен в Telegram!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Возвращаемся на экран авторизации
        Navigator.pop(context);
      } else {
        throw Exception('Не удалось отправить новый пароль');
      }
    } catch (e) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка смены пароля',
        message: 'Не удалось сменить пароль.\n\nПопробуйте позже или обратитесь к администратору.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showBotInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Инструкция по восстановлению'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Для восстановления пароля через Telegram бот:'),
            const SizedBox(height: 16),
            const Text('1. Найдите бота @t_co_service_bot в Telegram'),
            const Text('2. Нажмите "Начать" или отправьте команду /start'),
            const Text('3. Отправьте свой номер телефона:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _user?.phone ?? _phoneController.text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('4. Дождитесь кода восстановления'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ваш код восстановления:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _recoveryCode ?? 'Не сгенерирован',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _codeSent = true);
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A90E2),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Заголовок
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.lock_reset,
                        size: 48,
                        color: Color(0xFF4A90E2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Восстановление пароля',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Восстановите доступ к системе через Telegram бот',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Форма
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_codeSent) ...[
                          // Шаг 1: Ввод номера телефона
                          PhoneInputField(
                            controller: _phoneController,
                            labelText: 'Номер телефона',
                            hintText: '+7 (999) 123-45-67',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите номер телефона';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          ElevatedButton(
                            onPressed: _isLoading ? null : _sendRecoveryCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Отправить код восстановления'),
                          ),
                        ] else ...[
                          // Шаг 2: Ввод кода восстановления
                          Text(
                            'Код восстановления отправлен в Telegram на номер ${_user?.phone}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: 'Код восстановления',
                              hintText: '123456',
                              prefixIcon: const Icon(Icons.security),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(color: Colors.black87),
                              floatingLabelStyle: const TextStyle(color: Colors.black87),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите код восстановления';
                              }
                              if (value.length != 6) {
                                return 'Код должен содержать 6 цифр';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : () {
                                    setState(() {
                                      _codeSent = false;
                                      _attemptsLeft = 3;
                                      _codeController.clear();
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF4A90E2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(0, 50),
                                  ),
                                  child: const Text('Назад'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyCodeAndResetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A90E2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(0, 50),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Подтвердить'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Кнопка возврата
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Вернуться к авторизации',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
