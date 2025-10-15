import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Сервис для работы с Telegram ботом для восстановления паролей
class TelegramBotService {
  // Токен вашего Telegram бота
  static const String _botToken = '7819515456:AAEtWiR6A0ujxIpTgHlMpsqZw6fk0OLTYZY';
  static const String _botUrl = 'https://api.telegram.org/bot$_botToken';

  /// Отправка кода восстановления через Telegram бот
  static Future<bool> sendRecoveryCode({
    required String phoneNumber,
    required String recoveryCode,
    required String userName,
  }) async {
    try {
      // Формируем сообщение для пользователя
      final message = _buildRecoveryMessage(userName, recoveryCode);
      
      // Получаем chat_id по номеру телефона (если пользователь уже писал боту)
      final chatId = await _getChatIdByPhone(phoneNumber);
      
      if (chatId == null) {
        print('User with phone $phoneNumber not found in bot contacts');
        return false;
      }
      
      // Отправляем сообщение
      final success = await _sendMessage(chatId, message);
      
      if (success) {
        print('Recovery code sent to $phoneNumber via Telegram: $recoveryCode');
      }
      
      return success;
    } catch (e) {
      print('Error sending recovery code via Telegram: $e');
      return false;
    }
  }

  /// Отправка нового пароля через Telegram бот
  static Future<bool> sendNewPassword({
    required String phoneNumber,
    required String newPassword,
    required String userName,
  }) async {
    try {
      final message = _buildNewPasswordMessage(userName, newPassword);
      
      final chatId = await _getChatIdByPhone(phoneNumber);
      
      if (chatId == null) {
        print('User with phone $phoneNumber not found in bot contacts');
        return false;
      }
      
      final success = await _sendMessage(chatId, message);
      
      if (success) {
        print('New password sent to $phoneNumber via Telegram');
      }
      
      return success;
    } catch (e) {
      print('Error sending new password via Telegram: $e');
      return false;
    }
  }

  /// Получение chat_id по номеру телефона
  static Future<String?> _getChatIdByPhone(String phoneNumber) async {
    try {
      // Получаем список обновлений бота
      final response = await http.get(
        Uri.parse('$_botUrl/getUpdates'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updates = data['result'] as List;

        // Ищем пользователя по номеру телефона
        for (final update in updates) {
          final message = update['message'];
          if (message != null) {
            final contact = message['contact'];
            if (contact != null && contact['phone_number'] == phoneNumber) {
              return message['chat']['id'].toString();
            }
            
            // Также проверяем текст сообщения на наличие номера телефона
            final text = message['text']?.toString() ?? '';
            if (text.contains(phoneNumber.replaceAll(RegExp(r'[^\d]'), ''))) {
              return message['chat']['id'].toString();
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting chat_id by phone: $e');
      return null;
    }
  }

  /// Отправка сообщения через Telegram API
  static Future<bool> _sendMessage(String chatId, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$_botUrl/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'Markdown',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ok'] == true;
      } else {
        print('Telegram API error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending message via Telegram API: $e');
      return false;
    }
  }

  /// Формирование сообщения с кодом восстановления
  static String _buildRecoveryMessage(String userName, String recoveryCode) {
    return '''
🔐 *Восстановление пароля T-Co Service*

Здравствуйте, $userName!

Вы запросили восстановление пароля для системы T-Co Service.

*Ваш код восстановления: $recoveryCode*

Введите этот код в приложении для продолжения процедуры восстановления пароля.

⚠️ *Не передавайте этот код третьим лицам!*

Если вы не запрашивали восстановление пароля, проигнорируйте это сообщение.

---
*T-Co Service Support*
    ''';
  }

  /// Формирование сообщения с новым паролем
  static String _buildNewPasswordMessage(String userName, String newPassword) {
    return '''
✅ *Новый пароль T-Co Service*

Здравствуйте, $userName!

Ваш новый пароль для системы T-Co Service:

*$newPassword*

🔒 Рекомендуем сменить этот пароль после первого входа в систему.

⚠️ *Не передавайте пароль третьим лицам!*

---
*T-Co Service Support*
    ''';
  }

  /// Проверка статуса Telegram бота
  static Future<bool> checkBotStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_botUrl/getMe'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ok'] == true;
      }
      
      return false;
    } catch (e) {
      print('Telegram bot status check failed: $e');
      return false;
    }
  }

  /// Получение информации о боте
  static Future<Map<String, dynamic>?> getBotInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_botUrl/getMe'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true) {
          return data['result'];
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting bot info: $e');
      return null;
    }
  }

  /// Отправка инструкции пользователю о том, как связаться с ботом
  static Future<bool> sendBotInstructions(String phoneNumber) async {
    try {
      final chatId = await _getChatIdByPhone(phoneNumber);
      
      if (chatId == null) {
        print('User with phone $phoneNumber not found in bot contacts');
        return false;
      }

      final message = '''
🤖 *Инструкция по восстановлению пароля*

Для восстановления пароля через Telegram бот:

1. Найдите бота @t_co_service_bot в Telegram
2. Нажмите "Начать" или отправьте команду /start
3. Отправьте свой номер телефона: $phoneNumber
4. Дождитесь кода восстановления

*Альтернативно:* Обратитесь к администратору системы.

---
*T-Co Service Support*
      ''';

      return await _sendMessage(chatId, message);
    } catch (e) {
      print('Error sending bot instructions: $e');
      return false;
    }
  }
}