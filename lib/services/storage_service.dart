import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/equipment.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/service_request.dart';

class StorageService {
  final supabase.SupabaseClient _client;

  StorageService(this._client);

  static const String _usersKey = 'users_data';
  static const String _currentUserKey = 'current_user_inn';

  // Сохранить всех пользователей
  static Future<void> saveUsers(Map<String, User> users) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = <String, dynamic>{};
    
    users.forEach((inn, user) {
      usersJson[inn] = {
        'inn': user.inn,
        'companyName': user.companyName,
        'password': user.password,
        'equipment': user.equipment,
      };
    });
    
    await prefs.setString(_usersKey, jsonEncode(usersJson));
    print('💾 Данные пользователей сохранены');
  }

  // Загрузить всех пользователей
  Future<Map<String, Map<String, dynamic>>> loadUsers() async {
    try {
      print('Loading users from Supabase...');
      final response = await _client.from('users').select();
      print('Supabase response: $response');
      
      if (response == null) {
        print('No users found in Supabase');
        return {};
      }
      
      final users = response as List<dynamic>;
      print('Found ${users.length} users');
      
      final result = {
        for (var user in users)
          user['inn'] as String: user as Map<String, dynamic>
      };
      
      print('Processed users: ${result.keys.join(', ')}');
      return result;
    } catch (e) {
      print('Error loading users: $e');
      rethrow;
    }
  }

  // Сохранить текущего пользователя
  static Future<void> saveCurrentUser(String inn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, inn);
  }

  // Загрузить текущего пользователя
  static Future<String?> loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  // Очистить данные текущего пользователя (выход)
  Future<void> clearCurrentUser() async {
    await _client.auth.signOut();
  }

  // Создать тестовых пользователей по умолчанию
  static Map<String, User> _createDefaultUsers() {
    return {
      '1234567890': User(
        id: 'user-1',
        inn: '1234567890',
        companyName: 'T-company',
        lastName: 'Иванов',
        firstName: 'Иван',
        middleName: 'Иванович',
        position: 'Директор',
        email: 'ivanov@t-company.com',
        phone: '+79991234567',
        password: 'test123',
        role: UserRole.client,
        equipment: <String>[],
      ),
      '9876543210': User(
        id: 'user-2',
        inn: '9876543210',
        companyName: 'Тестовая компания',
        lastName: 'Петров',
        firstName: 'Петр',
        middleName: 'Петрович',
        position: 'Менеджер',
        email: 'petrov@test.com',
        phone: '+79997654321',
        password: 'demo123',
        role: UserRole.client,
        equipment: <String>[],
      ),
    };
  }

  // Сохранить конкретного пользователя
  static Future<void> saveUser(User user, Map<String, User> allUsers) async {
    allUsers[user.inn] = user;
    await saveUsers(allUsers);
  }

  // Очистить все данные (для отладки)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('🗑️ Все данные очищены');
  }

  // Сохранить данные для автовхода (запомнить меня)
  static Future<void> saveRememberMe(String inn, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remember_inn', inn);
    await prefs.setString('remember_password', password);
    await prefs.setBool('remember_me', true);
    print('💾 Данные для автовхода сохранены');
  }

  // Загрузить данные для автовхода
  static Future<Map<String, String>?> loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (!rememberMe) return null;
    
    final inn = prefs.getString('remember_inn');
    final password = prefs.getString('remember_password');
    
    if (inn != null && password != null) {
      return {'inn': inn, 'password': password};
    }
    
    return null;
  }

  // Очистить данные автовхода
  Future<void> clearRememberMe() async {
    await _client.auth.signOut();
  }

  // Проверить, включен ли автовход
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }

  Future<void> updateUser(User user) async {
    await _client.from('users').update(toJsonUser(user)).eq('id', user.id);
  }

  Future<void> createUser(User user) async {
    await _client.from('users').insert(toJsonUser(user));
  }

  Future<List<Equipment>> loadEquipment() async {
    final response = await _client.from('equipment').select();
    final equipment = response as List<dynamic>;
    return equipment
        .map((e) => Equipment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateEquipment(Equipment equipment) async {
    await _client.from('equipment').update(equipment.toJson()).eq('id', equipment.id);
  }

  Future<void> createEquipment(Equipment equipment) async {
    await _client.from('equipment').insert(equipment.toJson());
  }

  Future<List<ServiceRequest>> loadServiceRequests() async {
    final response = await _client.from('service_requests').select();
    final requests = response as List<dynamic>;
    return requests
        .map((r) => ServiceRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateServiceRequest(ServiceRequest request) async {
    await _client.from('service_requests').update(request.toJson()).eq('id', request.id);
  }

  Future<void> createServiceRequest(ServiceRequest request) async {
    await _client.from('service_requests').insert(request.toJson());
  }

  Future<void> setRememberMe(String inn, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: inn,
        password: password,
      );
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJsonUser(User user) {
    return {
      'id': user.id,
      'inn': user.inn,
      'company_name': user.companyName,
      'last_name': user.lastName,
      'first_name': user.firstName,
      'middle_name': user.middleName,
      'position': user.position,
      'email': user.email,
      'phone': user.phone,
      'password': user.password,
      'role': user.role.toString().split('.').last,
      'equipment': user.equipment,
    };
  }
} 