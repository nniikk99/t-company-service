import 'package:flutter/material.dart';

class TelegramWebAppService {
  static bool get isTelegramWebApp {
    return true; // включим для авто-логина демо
  }

  static Future<Map<String, dynamic>?> getUser() async {
    // Имитация получения данных пользователя из Telegram
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'id': '987654321',
      'first_name': 'Мария',
      'last_name': 'Петрова',
      'username': 'maria_lenta',
    };
  }

  static Future<Map<String, String>?> getTelegramUserData() async {
    final u = await getUser();
    if (u == null) return null;
    return {
      'telegram_id': u['id'].toString(),
      'first_name': u['first_name'] ?? '',
      'last_name': u['last_name'] ?? '',
      'username': u['username'] ?? '',
    };
  }

  static Future<void> closeWebApp() async {
    // Имитация закрытия WebApp
    print('Telegram WebApp closed');
  }

  static Future<void> expandWebApp() async {
    // Имитация расширения WebApp
    print('Telegram WebApp expanded');
  }

  static Future<void> showMainButton(String text, VoidCallback onPressed) async {
    // Имитация показа главной кнопки
    print('Main button shown: $text');
  }

  static Future<void> hideMainButton() async {
    // Имитация скрытия главной кнопки
    print('Main button hidden');
  }
}
