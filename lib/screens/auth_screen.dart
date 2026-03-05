import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/telegram_webapp_service.dart';
import '../services/storage_service.dart';
import '../services/app_router.dart';
import '../services/password_service.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart' as AppUserModel;
import '../theme/app_theme.dart';
import '../widgets/error_dialog.dart';
import '../widgets/phone_input_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _obscurePassword = true; // Для показа/скрытия пароля
  // согласие больше не требуется на экране входа
  final bool _consentGiven = true;
  String? _telegramUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Фокус для полей ввода
  final FocusNode _passwordFocusNode = FocusNode();
  
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
    
    // Listen to focus changes to update border color
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
    
    _animationController.forward();
    _checkTelegramAuth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordFocusNode.dispose();
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
      
      if (mounted) {
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
      backgroundColor: const Color(0xFF4A90E2), // Solid blue background like in the screenshot
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    // Main white card with logo and form
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Logo circle with "AI" letters
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A90E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Service name
                          const Text(
                            'AI Service',
                            style: TextStyle(
                              color: Color(0xFF4A90E2),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Tagline
                          const Text(
                            'Система управления сервисными заявками',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Phone number field with formatting
                          PhoneInputField(
                            controller: _phoneController,
                            hintText: 'Номер телефона',
                          ),
                          const SizedBox(height: 16),
                          
                          // Password field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Пароль',
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: !_isLoading ? _authenticate : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90E2),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Войти в систему',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Links row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/password-recovery');
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Забыли пароль?',
                                  style: TextStyle(
                                    color: Color(0xFF4A90E2),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/registration');
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Регистрация',
                                  style: TextStyle(
                                    color: Color(0xFF4A90E2),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
