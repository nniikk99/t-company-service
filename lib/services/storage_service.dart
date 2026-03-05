import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/client.dart';
import '../models/service_request.dart';
import '../models/price.dart';
import '../models/equipment.dart';
import '../models/notification.dart';
import '../models/site.dart';
import 'password_service.dart';
import 'supabase_service.dart';

class StorageService {
  static const String _usersKey = 'users';
  static const String _clientsKey = 'clients';
  static const String _requestsKey = 'requests';
  static const String _pricesKey = 'prices';
  static const String _equipmentKey = 'equipment';
  static const String _notificationsKey = 'notifications';

  // Функция хеширования пароля (используем централизованный сервис)
  static String _hashPassword(String password) {
    return PasswordService.hashPassword(password);
  }

  // Демо-данные
  static List<User> _getDemoUsers() {
    return [
      // Супер-админ (Т-Компания)
      User(
        id: '00000000-0000-0000-0000-000000000001',
        firstName: 'Администратор',
        lastName: 'Системы',
        email: 'admin@t-company.ru',
        phone: '+7 (981) 746-73-95',
        role: UserRole.superAdmin,
        position: 'Системный администратор',
        companyId: '00000000-0000-0000-0000-000000000000',
        companyName: 'Т-Компания',
        companyInn: '1234567890',
        passwordHash: _hashPassword('admin8602'), // SHA-256 хеш пароля admin8602
        telegramId: '555666777',
        consentToPersonalData: true,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
      ),
      
      // Ответственное лицо клиента (Тест компания)
      User(
        id: '9522bbae-8aff-4a09-a06f-62a5dcbd614a',
        firstName: 'Мария',
        lastName: 'Петрова',
        email: 'maria@lenta.ru',
        phone: '+7 (999) 111-11-11',
        role: UserRole.companyResponsible,
        position: 'Технический директор',
        companyId: '00000000-0000-0000-0000-000000000001',
        companyName: 'Тест компания',
        companyInn: '0000000001',
        passwordHash: _hashPassword('test'), // SHA-256 хеш пароля test
        telegramId: '987654321',
        consentToPersonalData: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      
      // Менеджер площадки - Иван Сидоров (только Лемана Про)
      User(
        id: '00000000-0000-0000-0000-000000000003',
        firstName: 'Иван',
        lastName: 'Сидоров',
        email: 'ivan@lenta.ru',
        phone: '+7 (495) 987-65-43',
        role: UserRole.siteManager,
        position: 'Менеджер объекта',
        companyId: '00000000-0000-0000-0000-000000000001',
        companyName: 'Тест компания',
        companyInn: '0000000001',
        canManageRequestsIndependently: false, // Требует одобрения
        assignedSiteIds: ['fe8767e3-7490-4f5a-ab73-9eec66c235af'], // Назначен только на Лемана Про
        createdBy: '9522bbae-8aff-4a09-a06f-62a5dcbd614a',
        passwordHash: _hashPassword('manager123'), // SHA-256 хеш пароля manager123
        telegramId: '111222333',
        consentToPersonalData: true,
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),

      // Пользователь, ожидающий одобрения
      User(
        id: '164fbf40-2862-49e5-a5c0-c22194a63bb2',
        firstName: 'Анна',
        lastName: 'Козлова',
        email: 'anna@test-company.ru',
        phone: '+7 (495) 111-22-33',
        role: UserRole.operatorPM,
        position: 'Оператор ПМ',
        companyId: '00000000-0000-0000-0000-000000000001',
        companyName: 'Тест компания',
        companyInn: '0000000001',
        assignedSiteIds: ['e98811cb-fe04-4eb1-ac4f-a62d4884bd02'], // Назначена на площадку
        passwordHash: _hashPassword('pending123'), // SHA-256 хеш пароля pending123
        telegramId: '444555666',
        consentToPersonalData: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  static List<Client> _getDemoClients() {
    return [
      Client(
        id: '00000000-0000-0000-0000-000000000001',
        name: 'Тест компания',
        address: 'г. Москва, тестовый адрес',
        contactPhone: '+7 (495) 000-00-01',
        contactEmail: 'test@company.ru',
        managerIds: ['demo_user_1'],
        responsibleIds: ['demo_user_2'],
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
    ];
  }

  static List<ServiceRequest> _getDemoRequests() {
    return [];
  }

  static List<Price> _getDemoPrices() {
    return [];
  }

  static List<Equipment> _getDemoEquipment() {
    return [];
  }

  static List<AppNotification> _getDemoNotifications() {
    return [];
  }

  // Получение пользователей
  static Future<List<User>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_usersKey);
    
    if (usersJson == null) {
      // Если данных нет, используем демо-данные
      final demoUsers = _getDemoUsers();
      await _saveUsers(demoUsers);
      return demoUsers;
    }
    
    final List<dynamic> usersList = jsonDecode(usersJson);
    return usersList.map((json) => User.fromJson(json)).toList();
  }

  // Сохранение пользователей
  static Future<void> _saveUsers(List<User> users) async {
    final prefs = await SharedPreferences.getInstance();
    final String usersJson = jsonEncode(users.map((user) => user.toJson()).toList());
    await prefs.setString(_usersKey, usersJson);
  }

  // Добавление или обновление пользователя
  static Future<void> saveUser(User user) async {
    final users = await getUsers();
    final index = users.indexWhere((u) => u.id == user.id);
    
    if (index != -1) {
      users[index] = user;
    } else {
      users.add(user);
    }
    
    await _saveUsers(users);
  }

  // Удаление пользователя
  static Future<void> deleteUser(String userId) async {
    final users = await getUsers();
    users.removeWhere((user) => user.id == userId);
    await _saveUsers(users);
  }

  // Получение текущего пользователя
  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? currentUserJson = prefs.getString('current_user');
    
    if (currentUserJson == null) {
      return null;
    }
    
    return User.fromJson(jsonDecode(currentUserJson));
  }

  // Сохранение текущего пользователя
  static Future<void> setCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final String userJson = jsonEncode(user.toJson());
    await prefs.setString('current_user', userJson);
    await prefs.setString('current_user_id', user.id);
  }

  // Удаление текущего пользователя (выход)
  static Future<void> clearCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('current_user_id');
  }

  // Получение клиентов
  static Future<List<Client>> getClients() async {
    final prefs = await SharedPreferences.getInstance();
    final String? clientsJson = prefs.getString(_clientsKey);
    
    if (clientsJson == null) {
      final demoClients = _getDemoClients();
      await _saveClients(demoClients);
      return demoClients;
    }
    
    final List<dynamic> clientsList = jsonDecode(clientsJson);
    return clientsList.map((json) => Client.fromJson(json)).toList();
  }

  // Сохранение клиентов
  static Future<void> _saveClients(List<Client> clients) async {
    final prefs = await SharedPreferences.getInstance();
    final String clientsJson = jsonEncode(clients.map((client) => client.toJson()).toList());
    await prefs.setString(_clientsKey, clientsJson);
  }

  // Добавление или обновление клиента
  static Future<void> saveClient(Client client) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c.id == client.id);
    
    if (index != -1) {
      clients[index] = client;
    } else {
      clients.add(client);
    }
    
    await _saveClients(clients);
  }

  // Получение заявок
  static Future<List<ServiceRequest>> getRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final String? requestsJson = prefs.getString(_requestsKey);
    
    if (requestsJson == null) {
      final demoRequests = _getDemoRequests();
      await _saveRequests(demoRequests);
      return demoRequests;
    }
    
    final List<dynamic> requestsList = jsonDecode(requestsJson);
    return requestsList.map((json) => ServiceRequest.fromJson(json)).toList();
  }

  // Сохранение заявок
  static Future<void> _saveRequests(List<ServiceRequest> requests) async {
    final prefs = await SharedPreferences.getInstance();
    final String requestsJson = jsonEncode(requests.map((request) => request.toJson()).toList());
    await prefs.setString(_requestsKey, requestsJson);
  }

  // Добавление или обновление заявки
  static Future<void> saveRequest(ServiceRequest request) async {
    final requests = await getRequests();
    final index = requests.indexWhere((r) => r.id == request.id);
    
    if (index != -1) {
      requests[index] = request;
    } else {
      requests.add(request);
    }
    
    await _saveRequests(requests);
  }

  // Удаление заявки
  static Future<void> deleteRequest(String requestId) async {
    final requests = await getRequests();
    requests.removeWhere((request) => request.id == requestId);
    await _saveRequests(requests);
  }

  // Получение прайс-листа
  static Future<List<Price>> getPrices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? pricesJson = prefs.getString(_pricesKey);
    
    if (pricesJson == null) {
      final demoPrices = _getDemoPrices();
      await _savePrices(demoPrices);
      return demoPrices;
    }
    
    final List<dynamic> pricesList = jsonDecode(pricesJson);
    return pricesList.map((json) => Price.fromJson(json)).toList();
  }

  // Сохранение прайс-листа
  static Future<void> _savePrices(List<Price> prices) async {
    final prefs = await SharedPreferences.getInstance();
    final String pricesJson = jsonEncode(prices.map((price) => price.toJson()).toList());
    await prefs.setString(_pricesKey, pricesJson);
  }

  // Добавление или обновление позиции прайс-листа
  static Future<void> savePrice(Price price) async {
    final prices = await getPrices();
    final index = prices.indexWhere((p) => p.id == price.id);
    
    if (index != -1) {
      prices[index] = price;
    } else {
      prices.add(price);
    }
    
    await _savePrices(prices);
  }

  // Получение оборудования
  static Future<List<Equipment>> getEquipment({String? companyId}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? equipmentJson = prefs.getString(_equipmentKey);
    
    if (equipmentJson == null) {
      final demoEquipment = _getDemoEquipment();
      await _saveEquipment(demoEquipment);
      return demoEquipment;
    }
    
    final List<dynamic> equipmentList = jsonDecode(equipmentJson);
    List<Equipment> equipment = equipmentList.map((json) => Equipment.fromJson(json)).toList();
    
    // Фильтруем по companyId если передан
    if (companyId != null) {
      equipment = equipment.where((e) => e.companyId == companyId).toList();
    }
    
    return equipment;
  }

  // Сохранение оборудования
  static Future<void> _saveEquipment(List<Equipment> equipment) async {
    final prefs = await SharedPreferences.getInstance();
    final String equipmentJson = jsonEncode(equipment.map((e) => e.toJson()).toList());
    await prefs.setString(_equipmentKey, equipmentJson);
  }

  // Добавление или обновление оборудования
  static Future<void> saveEquipmentItem(Equipment equipment) async {
    final equipmentList = await getEquipment();
    final index = equipmentList.indexWhere((e) => e.id == equipment.id);
    
    if (index != -1) {
      equipmentList[index] = equipment;
    } else {
      equipmentList.add(equipment);
    }
    
    await _saveEquipment(equipmentList);
  }

  // Обновление оборудования
  static Future<void> updateEquipment(Equipment equipment) async {
    await saveEquipmentItem(equipment);
  }

  // Удаление оборудования
  static Future<void> deleteEquipment(String equipmentId) async {
    final equipment = await getEquipment();
    equipment.removeWhere((e) => e.id == equipmentId);
    await _saveEquipment(equipment);
  }

  // Получение уведомлений
  static Future<List<AppNotification>> getNotifications({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString(_notificationsKey);
    
    if (notificationsJson == null) {
      final demoNotifications = _getDemoNotifications();
      await _saveNotifications(demoNotifications);
      return demoNotifications;
    }
    
    final List<dynamic> notificationsList = jsonDecode(notificationsJson);
    List<AppNotification> notifications = notificationsList
        .map((json) => AppNotification.fromJson(json))
        .toList();
    
    // Фильтруем по userId если передан
    if (userId != null) {
      notifications = notifications.where((n) => n.userId == userId).toList();
    }
    
    return notifications;
  }

  // Сохранение уведомлений
  static Future<void> _saveNotifications(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final String notificationsJson = jsonEncode(
      notifications.map((n) => n.toJson()).toList()
    );
    await prefs.setString(_notificationsKey, notificationsJson);
  }

  // Добавление или обновление уведомления
  static Future<void> saveNotification(AppNotification notification) async {
    final notifications = await getNotifications();
    final index = notifications.indexWhere((n) => n.id == notification.id);
    
    if (index != -1) {
      notifications[index] = notification;
    } else {
      notifications.add(notification);
    }
    
    await _saveNotifications(notifications);
  }

  // Отметка уведомления как прочитанного
  static Future<void> markNotificationAsRead(String notificationId) async {
    final notifications = await getNotifications();
    final index = notifications.indexWhere((n) => n.id == notificationId);
    
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      await _saveNotifications(notifications);
    }
  }

  // Получение площадок
  static Future<List<Site>> getSites({String? companyId}) async {
    List<Site> sites = [];
    
    try {
      // Сначала пытаемся загрузить из Supabase
      if (companyId != null) {
        sites = await SupabaseService.getSites(companyId);
      }
    } catch (e) {
      print('Ошибка загрузки площадок из Supabase: $e');
      // Если ошибка, используем демо-данные
      sites = _getDemoSites(companyId: companyId);
    }
    
    return sites;
  }

  // Демо-данные для площадок
  static List<Site> _getDemoSites({String? companyId}) {
    final allSites = [
      Site(
        id: '00000000-0000-0000-0000-000000000101', // UUID для площадки 1
        companyId: '00000000-0000-0000-0000-000000000001',
        companyInn: '0000000001',
        name: 'Магазин 212',
        address: 'г. Москва, ул. Тестовая, д. 212',
        phone: '+7 (495) 000-01-01',
        email: 'shop212@lenta.ru',
        createdAt: DateTime.now().subtract(const Duration(days: 180)),
      ),
      Site(
        id: 'e98811cb-fe04-4eb1-ac4f-a62d4884bd02', // UUID для площадки 2
        companyId: '00000000-0000-0000-0000-000000000001',
        companyInn: '0000000001',
        name: 'Склад №1',
        address: 'г. Москва, ул. Складская, д. 1',
        phone: '+7 (495) 000-01-02',
        email: 'warehouse1@lenta.ru',
        createdAt: DateTime.now().subtract(const Duration(days: 150)),
      ),
      Site(
        id: 'fe8767e3-7490-4f5a-ab73-9eec66c235af', // UUID для площадки 3
        companyId: '00000000-0000-0000-0000-000000000001',
        companyInn: '0000000001',
        name: 'Лемана Про',
        address: 'Автобусная 7',
        phone: '+7 (495) 000-01-03',
        email: 'office@lenta.ru',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
    ];
    
    if (companyId != null) {
      return allSites.where((site) => site.companyId == companyId).toList().cast<Site>();
    }
    
    return allSites.cast<Site>();
  }

  // Сохранение площадки
  static Future<void> saveSite(Site site) async {
    final prefs = await SharedPreferences.getInstance();
    final sites = await getSites();
    final updatedSites = [...sites, site];
    await prefs.setString('sites', jsonEncode(updatedSites.map((s) => s.toJson()).toList()));
  }

  // Удаление площадки
  static Future<void> deleteSite(String siteId) async {
    final prefs = await SharedPreferences.getInstance();
    final sites = await getSites();
    final updatedSites = sites.where((s) => s.id != siteId).toList();
    await prefs.setString('sites', jsonEncode(updatedSites.map((s) => s.toJson()).toList()));
  }

  // Сохранение оборудования
  static Future<void> saveEquipment(Equipment equipment) async {
    await saveEquipmentItem(equipment);
  }

  // Очистка всех данных
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
