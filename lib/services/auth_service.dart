import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as AppUser;
import '../models/client.dart';
import 'supabase_service.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Создание пользователя
  static Future<AppUser.User> createUser(AppUser.User user) async {
    final response = await _client
        .from('user_profiles')
        .insert(user.toJson())
        .select()
        .single();
    
    return AppUser.User.fromJson(response);
  }

  // Поиск компании по ИНН
  static Future<String?> findCompanyByInn(String inn) async {
    final response = await _client
        .from('companies')
        .select('id')
        .eq('inn', inn)
        .maybeSingle();
    
    return response?['id'];
  }

  // Создание компании
  static Future<String> createCompany({
    required String name,
    required String inn,
    String? description,
  }) async {
    final response = await _client.from('companies').insert({
      'name': name,
      'inn': inn,
      'description': description,
    }).select().single();

    return response['id'];
  }

  // Аутентификация по телефону и паролю
  static Future<AppUser.User?> signInWithPhoneAndPassword(String phone, String password) async {
    try {
      // Хэшируем пароль для сравнения
      final hashedPassword = _hashPassword(password);
      
      final response = await _client
          .from('user_profiles')
          .select('*, companies(name)')
          .eq('phone', phone)
          .eq('password_hash', hashedPassword)
          .eq('is_active', true)
          .maybeSingle();
      
      if (response != null) {
        return AppUser.User.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Sign in with phone error: $e');
      return null;
    }
  }

  // Аутентификация по email и паролю
  static Future<AppUser.User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Хэшируем пароль для сравнения
      final hashedPassword = _hashPassword(password);
      
      final response = await _client
          .from('user_profiles')
          .select('*, companies(name)')
          .eq('email', email)
          .eq('password_hash', hashedPassword)
          .eq('is_active', true)
          .maybeSingle();
      
      if (response != null) {
        return AppUser.User.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  // Поиск пользователя по Telegram ID для автологина
  static Future<AppUser.User?> getUserByTelegramId(String telegramId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('*, companies(name)')
          .eq('telegram_id', telegramId)
          .eq('is_active', true)
          .maybeSingle();
      
      if (response != null) {
        return AppUser.User.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Get user by telegram error: $e');
      return null;
    }
  }

  // Привязка Telegram к пользователю
  static Future<void> linkTelegramToUser(String userId, String telegramId, String? telegramUsername) async {
    await _client
        .from('user_profiles')
        .update({
          'telegram_id': telegramId,
          'telegram_username': telegramUsername,
        })
        .eq('id', userId);
  }

  // Смена пароля
  static Future<void> changePassword(String userId, String newPassword) async {
    final hashedPassword = _hashPassword(newPassword);
    
    await _client
        .from('user_profiles')
        .update({'password_hash': hashedPassword})
        .eq('id', userId);
  }

  // Одобрение пользователя
  static Future<void> approveUser(String userId, String approvedBy, AppUser.UserRole newRole) async {
    await _client
        .from('user_profiles')
        .update({
          'role': _roleToString(newRole),
          'created_by': approvedBy,
          'is_active': true,
        })
        .eq('id', userId);
  }

  // Получение пользователей, ожидающих одобрения
  static Future<List<AppUser.User>> getPendingUsers(String companyId) async {
    final response = await _client
        .from('user_profiles')
        .select('*, companies(name)')
        .eq('company_id', companyId)
        .eq('role', 'pendingApproval')
        .order('created_at');
    
    return (response as List)
        .map((json) => AppUser.User.fromJson(json))
        .toList();
  }

  // Получение всех пользователей компании
  static Future<List<AppUser.User>> getCompanyUsers(String companyId) async {
    final response = await _client
        .from('user_profiles')
        .select('*, companies(name)')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('created_at');
    
    return (response as List)
        .map((json) => AppUser.User.fromJson(json))
        .toList();
  }

  // Назначение менеджеров площадок
  static Future<void> assignSiteManager(String userId, List<String> siteIds, bool canManageIndependently) async {
    await _client
        .from('user_profiles')
        .update({
          'role': 'site_manager',
          'assigned_site_ids': siteIds,
          'can_manage_requests_independently': canManageIndependently,
        })
        .eq('id', userId);
  }

  // Вспомогательные методы
  static String _hashPassword(String password) {
    // Простое хэширование для демо (в продакшене использовать bcrypt)
    return password; // TODO: Implement proper hashing
  }

  static String _roleToString(AppUser.UserRole role) {
    switch (role) {
      case AppUser.UserRole.superAdmin:
        return 'superAdmin';
      case AppUser.UserRole.companyResponsible:
        return 'companyResponsible';
      case AppUser.UserRole.supplier:
        return 'supplier';
      case AppUser.UserRole.siteManager:
        return 'siteManager';
      case AppUser.UserRole.operatorPM:
        return 'operatorPM';
      case AppUser.UserRole.engineer:
        return 'engineer';
      case AppUser.UserRole.pendingApproval:
        return 'pendingApproval';
      case AppUser.UserRole.administrator:
        return 'administrator';
      case AppUser.UserRole.admin:
        return 'admin';
      case AppUser.UserRole.clientManager:
        return 'clientManager';
      case AppUser.UserRole.clientResponsible:
        return 'clientResponsible';
      case AppUser.UserRole.contactPerson:
        return 'contactPerson';
    }
  }
}
