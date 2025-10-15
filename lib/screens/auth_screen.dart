import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/telegram_webapp_service.dart';
import '../services/storage_service.dart';
import '../services/app_router.dart';
import '../services/password_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart' as AppUserModel;
import '../theme/app_theme.dart';
import '../widgets/modern_card.dart';
import '../widgets/error_dialog.dart';
import '../widgets/phone_input_field.dart';
import 'supabase_test_screen.dart';
import 'database_check_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _obscurePassword = true; // Для показа/скрытия пароля
  // согласие больше не требуется на экране входа
  bool _consentGiven = true;
  String? _telegramUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Контроллеры для полей ввода
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _checkTelegramAuth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkTelegramAuth() async {
    if (TelegramWebAppService.isTelegramWebApp) {
      final prefs = await SharedPreferences.getInstance();
      final skipOnce = prefs.getBool('skip_auto_login_once') ?? false;
      if (skipOnce) {
        // Сбрасываем флаг и выходим без автологина
        await prefs.remove('skip_auto_login_once');
        return;
      }

      final telegramData = await TelegramWebAppService.getTelegramUserData();
      if (telegramData != null) {
        setState(() {
          _telegramUser = telegramData['first_name'] ?? 'Пользователь';
        });
        // Попытка автологина через Telegram ID (временно отключено для тестирования)
        // await _tryTelegramAutoLogin(telegramData['telegram_id']!);
      }
    }
  }

  Future<void> _tryTelegramAutoLogin(String telegramId) async {
    try {
      // Ищем пользователя по Telegram ID
      final users = await StorageService.getUsers();
      final user = users.firstWhere(
        (u) => u.telegramId == telegramId && u.isActive,
        orElse: () => throw Exception('User not found'),
      );

      // Проверяем роль пользователя
      if (user.needsApproval) {
        _showErrorSnackBar('Ваш аккаунт ожидает одобрения');
        return;
      }

      // Автоматический вход
      await _loginUser(user);
      
    } catch (e) {
      print('Auto login failed: $e');
      // Продолжаем обычную авторизацию
    }
  }

  Future<void> _loginUser(AppUserModel.User user) async {
    // Сохраняем данные сессии
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', user.id);
    await prefs.setBool('is_logged_in', true);

    // Переход в приложение
    if (mounted) {
      Navigator.pushReplacementNamed(
        context, 
        AppRouter.dashboard,
        arguments: user,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Нормализация номера телефона (убираем все символы кроме цифр)
  String _normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  String _roleToString(AppUserModel.UserRole role) {
    switch (role) {
      case AppUserModel.UserRole.superAdmin:
        return 'super_admin';
      case AppUserModel.UserRole.administrator:
        return 'administrator';
      case AppUserModel.UserRole.companyResponsible:
        return 'company_responsible';
      case AppUserModel.UserRole.supplier:
        return 'supplier';
      case AppUserModel.UserRole.siteManager:
        return 'site_manager';
      case AppUserModel.UserRole.operatorPM:
        return 'operator_pm';
      case AppUserModel.UserRole.engineer:
        return 'engineer';
      case AppUserModel.UserRole.pendingApproval:
        return 'pending_approval';
      case AppUserModel.UserRole.admin:
        return 'admin';
      case AppUserModel.UserRole.clientManager:
        return 'client_manager';
      case AppUserModel.UserRole.clientResponsible:
        return 'client_responsible';
      case AppUserModel.UserRole.contactPerson:
        return 'contact_person';
    }
  }

  Future<void> _authenticate() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ErrorDialog.show(
        context: context,
        title: 'Заполните все поля',
        message: 'Пожалуйста, введите номер телефона и пароль для входа в систему.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      AppUserModel.User user;
      final normalizedPhone = _normalizePhoneNumber(_phoneController.text.trim());
      
      // Сначала пробуем найти в Supabase через AuthService
      try {
        print('Searching in Supabase for phone: ${_phoneController.text.trim()}');
        final supabaseUser = await AuthService.signInWithPhoneAndPassword(
          _phoneController.text.trim(),
          _passwordController.text,
        );
        if (supabaseUser == null) {
          throw Exception('Пользователь не найден');
        }
        user = supabaseUser;
        print('Found user in Supabase: ${user.id}');
        
        // Сохранение сессии
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', user.id);
        await prefs.setBool('is_logged_in', true);

        // Навигация
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRouter.dashboard, arguments: user);
        }
        return;
      } catch (e) {
        print('Not found in Supabase: $e');
        // Если не найден в Supabase, ищем в локальном хранилище
        print('Searching in local storage for phone: ${_phoneController.text.trim()}');
        print('Normalized phone: $normalizedPhone');
        final users = await StorageService.getUsers();
        print('Local users count: ${users.length}');
        
        // Выводим все номера телефонов для отладки
        for (int i = 0; i < users.length; i++) {
          print('User $i: phone="${users[i].phone}", normalized="${_normalizePhoneNumber(users[i].phone)}"');
        }
        
        user = users.firstWhere(
          (u) => _normalizePhoneNumber(u.phone) == normalizedPhone,
          orElse: () => throw Exception('Пользователь не найден'),
        );
        print('Found user in local storage: ${user.id}');
      }

      // Проверка пароля для локального пользователя
      final inputPasswordHash = _hashPassword(_passwordController.text);
      print('Input password hash: $inputPasswordHash');
      print('Stored password hash: ${user.passwordHash}');
      if (user.passwordHash != inputPasswordHash) {
        throw Exception('Неверный пароль');
      }

      // Пытаемся загрузить актуальные данные из Supabase
      try {
        final supabaseUser = await SupabaseService.getUserProfile(user.id);
        if (supabaseUser != null) {
          user = AppUserModel.User.fromJson(supabaseUser);
          print('✅ Загружены актуальные данные из Supabase');
          // Обновляем локальное хранилище
          await StorageService.saveUser(user);
          await StorageService.setCurrentUser(user);
        }
      } catch (e) {
        print('⚠️ Не удалось загрузить данные из Supabase: $e');
        
        // Если пользователь не найден в Supabase, создаем запись
        if (e.toString().contains('multiple (or no) rows returned')) {
          print('🔄 Создаем запись пользователя в Supabase...');
          try {
            await SupabaseService.createUserProfile(
              userId: user.id,
              email: user.email,
              firstName: user.firstName,
              lastName: user.lastName,
              role: _roleToString(user.role),
              phone: user.phone,
              position: user.position,
              companyName: user.companyName,
              companyInn: user.companyInn,
              passwordHash: user.passwordHash,
              canManageRequestsIndependently: user.canManageRequestsIndependently,
            );
            print('✅ Запись пользователя создана в Supabase');
            
            // Теперь попробуем загрузить данные снова
            final supabaseUser = await SupabaseService.getUserProfile(user.id);
            if (supabaseUser != null) {
              user = AppUserModel.User.fromJson(supabaseUser);
              print('✅ Загружены данные из Supabase после создания');
              await StorageService.saveUser(user);
              await StorageService.setCurrentUser(user);
            }
          } catch (createError) {
            print('❌ Ошибка создания записи в Supabase: $createError');
          }
        }
        
        // Продолжаем с локальными данными
      }
      
      // Сохранение сессии
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user.id);
      await prefs.setBool('is_logged_in', true);

      // Навигация
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.dashboard, arguments: user);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Произошла ошибка при входе в систему.';
        String errorTitle = 'Ошибка входа';
        
        if (e.toString().contains('Пользователь не найден')) {
          errorTitle = 'Пользователь не найден';
          errorMessage = 'Пользователь с указанным номером телефона не найден в системе.\n\nПроверьте правильность номера или обратитесь к администратору.';
        } else if (e.toString().contains('Неверный пароль')) {
          errorTitle = 'Неверный пароль';
          errorMessage = 'Введенный пароль неверный.\n\nПроверьте правильность пароля или обратитесь к администратору для восстановления доступа.';
        } else if (e.toString().contains('PostgrestException')) {
          errorTitle = 'Ошибка подключения';
          errorMessage = 'Не удалось подключиться к серверу.\n\nПроверьте подключение к интернету и попробуйте снова.';
        }
        
        ErrorDialog.show(
          context: context,
          title: errorTitle,
          message: errorMessage,
          onRetry: () {
            _phoneController.clear();
            _passwordController.clear();
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _hashPassword(String password) {
    return PasswordService.hashPassword(password);
  }

  Future<void> _demoLogin(String userId) async {
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      final users = await StorageService.getUsers();
      final user = users.firstWhere((u) => u.id == userId, orElse: () => users.first);
      
      if (user != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard', arguments: user);
      }
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка входа: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
      setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A90E2), // Синий сверху
              Color(0xFF6B73FF), // Фиолетовый снизу
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    
                    // Логотип и заголовок
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Иконка логотипа (скутер в круге)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo/IMG_1897.PNG',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Заголовок
                          Text(
                            'T-Co Service',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4A90E2),
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Система управления сервисными заявками',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),

                    // Поля ввода
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Поле телефона
                          PhoneInputField(
                            controller: _phoneController,
                            labelText: 'Номер телефона',
                            hintText: '+7 (999) 123-45-67',
                          ),
                          const SizedBox(height: 16),
                          
                          // Поле пароля
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              hintText: 'Введите пароль',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
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
                          ),
                          const SizedBox(height: 12),
                          
                          // Кнопка восстановления пароля
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/password-recovery');
                              },
                              child: const Text(
                                'Забыли пароль?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),
                          
                          // Кнопка входа
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: !_isLoading ? _authenticate : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black87,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.login, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Войти в систему',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          
                          // Кнопка регистрации
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/registration');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Регистрация',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Кнопка очистки кеша (только для разработки)
                          OutlinedButton(
                            onPressed: () async {
                              await StorageService.clearAll();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Кеш очищен! Данные обновлены.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.orange[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '🗑️ Очистить кеш',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                          
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SupabaseTestScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '🔧 Тест Supabase подключения',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
