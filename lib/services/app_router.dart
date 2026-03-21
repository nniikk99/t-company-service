import 'package:flutter/material.dart';
import '../models/user.dart';
import '../screens/auth_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/equipment_screen.dart';
import '../screens/requests_screen.dart';
import '../screens/main_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/password_recovery_screen.dart';
import '../screens/telegram_bot_test_screen.dart';
import '../screens/database_check_screen.dart';
import '../screens/database_management_screen.dart';

class AppRouter {
  static const String auth = '/auth';
  static const String registration = '/registration';
  static const String passwordRecovery = '/password-recovery';
  static const String telegramBotTest = '/telegram-bot-test';
  static const String dashboard = '/dashboard';
  static const String equipment = '/equipment';
  static const String requests = '/requests';
  static const String admin = '/admin';
  static const String databaseCheck = '/database-check';
  static const String profile = '/profile';
  static const String notifications = '/notifications';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case auth:
        return MaterialPageRoute(builder: (_) => const AuthScreen());
        
      case registration:
        return MaterialPageRoute(builder: (_) => const RegistrationScreen());
      
      case passwordRecovery:
        return MaterialPageRoute(builder: (_) => const PasswordRecoveryScreen());
      
      case telegramBotTest:
        return MaterialPageRoute(builder: (_) => const TelegramBotTestScreen());
      
      case databaseCheck:
        final user = settings.arguments as User?;
        if (user == null) {
          return MaterialPageRoute(builder: (_) => const DatabaseCheckScreen());
        }
        return MaterialPageRoute(builder: (_) => DatabaseManagementScreen(adminUser: user));
      
      case dashboard:
        final user = settings.arguments as User?;
        if (user == null) {
          return MaterialPageRoute(builder: (_) => const AuthScreen());
        }
        return MaterialPageRoute(
          builder: (_) => MainScreen(user: user),
        );
      
      case equipment:
        final user = settings.arguments as User?;
        return MaterialPageRoute(
          builder: (_) => EquipmentScreen(user: user),
        );
      
      case requests:
        final user = settings.arguments as User?;
        return MaterialPageRoute(
          builder: (_) => RequestsScreen(user: user),
        );
      
      case admin:
        final user = settings.arguments as User?;
        if (user == null || user.role != UserRole.administrator) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text('Доступ запрещен'),
              ),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => AdminScreen(user: user),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Страница не найдена'),
            ),
          ),
        );
    }
  }

  // Получить стартовый роут в зависимости от роли пользователя
  static String getInitialRoute(User? user) {
    if (user == null) return auth;
    return dashboard;
  }

  // Получить доступные роуты для роли пользователя
  static List<String> getAvailableRoutes(UserRole role) {
    switch (role) {
      case UserRole.administrator:
        return [dashboard, equipment, requests, admin, profile, notifications];
      case UserRole.clientResponsible:
      case UserRole.companyResponsible:
        return [dashboard, equipment, requests, profile, notifications];
      case UserRole.clientManager:
        return [dashboard, equipment, requests, profile, notifications];
      case UserRole.contactPerson:
      case UserRole.siteManager:
      case UserRole.operatorPM:
        return [dashboard, equipment, requests, profile, notifications];
      case UserRole.pendingApproval:
      default:
        return [auth];
    }
  }

  // Проверить доступ к роуту
  static bool canAccessRoute(String route, UserRole role) {
    return getAvailableRoutes(role).contains(route);
  }
}
