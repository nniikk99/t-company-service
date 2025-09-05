import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/client.dart';
import '../models/service_request.dart';
import '../models/price.dart';
import '../models/equipment.dart';

class StorageService {
  static const String _usersKey = 'users';
  static const String _clientsKey = 'clients';
  static const String _requestsKey = 'requests';
  static const String _pricesKey = 'prices';
  static const String _equipmentKey = 'equipment';

  // Демо-данные
  static List<User> _getDemoUsers() {
    return [
      User(
        id: 'demo_user_1',
        telegramId: '123456789',
        firstName: 'Александр',
        lastName: 'Петров',
        phone: '+7 (999) 123-45-67',
        email: 'alex@example.com',
        role: UserRole.clientManager,
        clientId: 'demo_client_1',
        consentToPersonalData: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      User(
        id: 'demo_user_2',
        telegramId: '987654321',
        firstName: 'Мария',
        lastName: 'Иванова',
        phone: '+7 (999) 987-65-43',
        email: 'maria@example.com',
        role: UserRole.clientResponsible,
        clientId: 'demo_client_1',
        consentToPersonalData: true,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      User(
        id: 'admin_user',
        telegramId: '555666777',
        firstName: 'Админ',
        lastName: 'Админов',
        phone: '+7 (999) 555-66-77',
        email: 'admin@example.com',
        role: UserRole.admin,
        consentToPersonalData: true,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ];
  }

  static List<Client> _getDemoClients() {
    return [
      Client(
        id: 'demo_client_1',
        name: 'ООО "ТехноСервис"',
        address: 'г. Москва, ул. Техническая, д. 1',
        contactPhone: '+7 (495) 123-45-67',
        contactEmail: 'info@technoservice.ru',
        managerIds: ['demo_user_1'],
        responsibleIds: ['demo_user_2'],
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
    ];
  }

  static List<Equipment> _getDemoEquipment() {
    return [
      Equipment(
        id: 'equipment_1',
        clientId: 'demo_client_1',
        title: 'GT110',
        model: 'GT110',
        location: 'Цех №1',
        address: 'г. Москва, ул. Техническая, д. 1, Цех №1',
        status: EquipmentStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      Equipment(
        id: 'equipment_2',
        clientId: 'demo_client_1',
        title: 'GT180',
        model: 'GT180',
        location: 'Цех №2',
        address: 'г. Москва, ул. Техническая, д. 1, Цех №2',
        status: EquipmentStatus.maintenance,
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
      ),
    ];
  }

  static List<ServiceRequest> _getDemoRequests() {
    return [
      ServiceRequest(
        id: 'request_1',
        clientId: 'demo_client_1',
        userId: 'demo_user_1',
        type: RequestType.repair,
        title: 'Ремонт GT110',
        description: 'Необходим ремонт двигателя GT110 в цехе №1',
        status: RequestStatus.pending,
        equipmentId: 'equipment_1',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      ServiceRequest(
        id: 'request_2',
        clientId: 'demo_client_1',
        userId: 'demo_user_2',
        type: RequestType.specialistVisit,
        title: 'Техническое обслуживание GT180',
        description: 'Плановое техническое обслуживание GT180',
        status: RequestStatus.inProgress,
        equipmentId: 'equipment_2',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  static List<Price> _getDemoPrices() {
    return [
      Price(
        id: 'price_1',
        clientId: 'demo_client_1',
        itemName: 'Ремонт двигателя',
        description: 'Ремонт двигателя GT110',
        cost: 15000.0,
        unit: 'шт',
      ),
      Price(
        id: 'price_2',
        clientId: 'demo_client_1',
        itemName: 'Техническое обслуживание',
        description: 'Плановое ТО GT180',
        cost: 8000.0,
        unit: 'шт',
      ),
    ];
  }

  // Методы для работы с пользователями
  static Future<List<User>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    
    if (usersJson == null) {
      // Возвращаем демо-данные при первом запуске
      final demoUsers = _getDemoUsers();
      await saveUsers(demoUsers);
      return demoUsers;
    }
    
    final List<dynamic> usersList = jsonDecode(usersJson);
    return usersList.map((json) => User.fromJson(json)).toList();
  }

  static Future<void> saveUsers(List<User> users) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = jsonEncode(users.map((user) => user.toJson()).toList());
    await prefs.setString(_usersKey, usersJson);
  }

  // Методы для работы с клиентами
  static Future<List<Client>> getClients() async {
    final prefs = await SharedPreferences.getInstance();
    final clientsJson = prefs.getString(_clientsKey);
    
    if (clientsJson == null) {
      final demoClients = _getDemoClients();
      await saveClients(demoClients);
      return demoClients;
    }
    
    final List<dynamic> clientsList = jsonDecode(clientsJson);
    return clientsList.map((json) => Client.fromJson(json)).toList();
  }

  static Future<void> saveClients(List<Client> clients) async {
    final prefs = await SharedPreferences.getInstance();
    final clientsJson = jsonEncode(clients.map((client) => client.toJson()).toList());
    await prefs.setString(_clientsKey, clientsJson);
  }

  // Методы для работы с заявками
  static Future<List<ServiceRequest>> getRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final requestsJson = prefs.getString(_requestsKey);
    
    if (requestsJson == null) {
      final demoRequests = _getDemoRequests();
      await saveRequests(demoRequests);
      return demoRequests;
    }
    
    final List<dynamic> requestsList = jsonDecode(requestsJson);
    return requestsList.map((json) => ServiceRequest.fromJson(json)).toList();
  }

  static Future<void> saveRequests(List<ServiceRequest> requests) async {
    final prefs = await SharedPreferences.getInstance();
    final requestsJson = jsonEncode(requests.map((request) => request.toJson()).toList());
    await prefs.setString(_requestsKey, requestsJson);
  }

  // Методы для работы с ценами
  static Future<List<Price>> getPrices() async {
    final prefs = await SharedPreferences.getInstance();
    final pricesJson = prefs.getString(_pricesKey);
    
    if (pricesJson == null) {
      final demoPrices = _getDemoPrices();
      await savePrices(demoPrices);
      return demoPrices;
    }
    
    final List<dynamic> pricesList = jsonDecode(pricesJson);
    return pricesList.map((json) => Price.fromJson(json)).toList();
  }

  static Future<void> savePrices(List<Price> prices) async {
    final prefs = await SharedPreferences.getInstance();
    final pricesJson = jsonEncode(prices.map((price) => price.toJson()).toList());
    await prefs.setString(_pricesKey, pricesJson);
  }

  // Методы для работы с оборудованием
  static Future<List<Equipment>> getEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    final equipmentJson = prefs.getString(_equipmentKey);
    
    if (equipmentJson == null) {
      final demoEquipment = _getDemoEquipment();
      await saveEquipment(demoEquipment);
      return demoEquipment;
    }
    
    final List<dynamic> equipmentList = jsonDecode(equipmentJson);
    return equipmentList.map((json) => Equipment.fromJson(json)).toList();
  }

  static Future<void> saveEquipment(List<Equipment> equipment) async {
    final prefs = await SharedPreferences.getInstance();
    final equipmentJson = jsonEncode(equipment.map((eq) => eq.toJson()).toList());
    await prefs.setString(_equipmentKey, equipmentJson);
  }
}
