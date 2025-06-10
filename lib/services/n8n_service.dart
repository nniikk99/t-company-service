import 'dart:convert';
import 'package:http/http.dart' as http;

class N8nService {
  static const String baseUrl = 'https://n8n.t-company-service.com/webhook';
  static const bool isTestMode = true; // Включаем тестовый режим

  // Регистрация пользователя
  static Future<bool> registerUser({
    required String inn,
    required String email,
  }) async {
    try {
      if (isTestMode) {
        print('Test Mode: Registering user');
        print('INN: $inn');
        print('Email: $email');
        // Имитируем задержку
        await Future.delayed(Duration(seconds: 2));
        return true;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'inn': inn,
          'email': email,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }

  // Создание заявки на обслуживание
  static Future<bool> createServiceRequest({
    required String equipmentId,
    required String type,
    required String message,
    required String userEmail,
    required String userTelegramId,
  }) async {
    try {
      if (isTestMode) {
        print('Test Mode: Creating service request');
        print('Equipment ID: $equipmentId');
        print('Type: $type');
        print('Message: $message');
        await Future.delayed(Duration(seconds: 2));
        return true;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/service-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'equipmentId': equipmentId,
          'type': type,
          'message': message,
          'userEmail': userEmail,
          'userTelegramId': userTelegramId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating service request: $e');
      return false;
    }
  }
} 