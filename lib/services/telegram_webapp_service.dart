import 'package:flutter/material.dart';

class TelegramWebAppService {
  static bool get isTelegramWebApp {
    return false; // В демо-режиме всегда false
  }

  static Future<Map<String, dynamic>?> getUser() async {
    // Имитация получения данных пользователя из Telegram
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'id': 'demo_user_1',
      'first_name': 'Александр',
      'last_name': 'Петров',
      'username': 'alex_petrov',
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
