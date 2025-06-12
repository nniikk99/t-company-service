import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/equipment.dart';

class StorageService {
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
        'equipment': user.equipment.map((eq) => eq.toJson()).toList(),
      };
    });
    
    await prefs.setString(_usersKey, jsonEncode(usersJson));
    print('💾 Данные пользователей сохранены');
  }

  // Загрузить всех пользователей
  static Future<Map<String, User>> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersString = prefs.getString(_usersKey);
    
    if (usersString == null) {
      print('📂 Данные пользователей не найдены, создаем тестового пользователя');
      return _createDefaultUsers();
    }

    try {
      final usersJson = jsonDecode(usersString) as Map<String, dynamic>;
      final users = <String, User>{};
      
      usersJson.forEach((inn, userData) {
        final equipmentList = (userData['equipment'] as List<dynamic>)
            .map((eq) => Equipment.fromJson(eq as Map<String, dynamic>))
            .toList();
            
        users[inn] = User(
          inn: userData['inn'],
          companyName: userData['companyName'],
          password: userData['password'],
          equipment: equipmentList,
        );
      });
      
      print('📂 Загружено ${users.length} пользователей');
      return users;
    } catch (e) {
      print('❌ Ошибка загрузки данных: $e');
      return _createDefaultUsers();
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
  static Future<void> clearCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // Создать тестовых пользователей по умолчанию
  static Map<String, User> _createDefaultUsers() {
    return {
      '1234567890': User(
        inn: '1234567890',
        companyName: 'T-company',
        password: 'test123',
        equipment: <Equipment>[],
      ),
      '9876543210': User(
        inn: '9876543210',
        companyName: 'Тестовая компания',
        password: 'demo123',
        equipment: <Equipment>[],
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
  static Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_inn');
    await prefs.remove('remember_password');
    await prefs.setBool('remember_me', false);
    print('🗑️ Данные автовхода очищены');
  }

  // Проверить, включен ли автовход
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }
} 