import 'package:http/http.dart' as http;
import 'dart:convert';

class TelegramService {
  static const String _baseUrl = 'https://api.telegram.org/bot';
  static const String _botToken = '7819515456:AAEtWiR6A0ujxIpTgHlMpsqZw6fk0OLTYZY'; // Замени на свой токен

  // Отправка сообщения
  static Future<bool> sendMessage({
    required String chatId,
    required String text,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_botToken/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'HTML',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending Telegram message: $e');
      return false;
    }
  }

  // Получение обновлений (для вебхука)
  static Future<Map<String, dynamic>?> getUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_botToken/getUpdates'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting Telegram updates: $e');
      return null;
    }
  }

  // Установка вебхука
  static Future<bool> setWebhook(String webhookUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_botToken/setWebhook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': webhookUrl,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error setting Telegram webhook: $e');
      return false;
    }
  }

  Future<bool> checkUserExists(String inn) async {
    // TODO: реализуй или убери
    return false;
  }

  Future<void> addUser({required String inn, required String companyName, required String password}) async {
    // TODO: реализуй или убери
  }
} 