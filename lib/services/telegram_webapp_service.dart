import 'package:flutter/material.dart';

class TelegramWebAppService {
  static bool get isAvailable {
    try {
      return true; // Временно всегда возвращаем true для тестирования
    } catch (e) {
      return false;
    }
  }

  // Инициализация
  static void init() {
    // Временно ничего не делаем
  }

  // Получение данных пользователя
  static Map<String, String>? get user {
    // Временно возвращаем тестовые данные
    return {
      'first_name': 'Test',
      'last_name': 'User',
      'username': 'testuser',
    };
  }

  // Получение chat_id
  static String? get chatId {
    return '123456789';
  }

  // Отправка данных
  static void sendData(String data) {
    print('Sending data: $data');
  }

  // Закрытие приложения
  static void close() {
    print('Closing app');
  }

  // Получение темы
  static ThemeData getTheme() {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: Colors.blue,
        secondary: Colors.blueAccent,
        background: Colors.white,
        surface: Colors.grey[100]!,
        onPrimary: Colors.white,
        onBackground: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
    );
  }

  static Color _parseColor(String? color) {
    if (color == null) return Colors.white;
    return Color(int.parse(color.replaceAll('#', '0xFF')));
  }
} 