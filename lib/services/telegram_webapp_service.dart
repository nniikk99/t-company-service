import 'package:flutter/material.dart';
import 'dart:html' as html;

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
    // Инициализация Telegram WebApp
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
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
      ),
    );
  }

  static Color _parseColor(String? color) {
    if (color == null) return Colors.white;
    return Color(int.parse(color.replaceAll('#', '0xFF')));
  }

  static void showAlert(String message) {
    html.window.alert(message);
  }

  static void showConfirm(String message, Function(bool) onResult) {
    final result = html.window.confirm(message);
    onResult(result);
  }
} 