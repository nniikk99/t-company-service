import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

class TelegramWebAppService {
  static bool get isAvailable {
    if (html.window.navigator.userAgent.contains('TelegramWebApp')) {
      return js.context.hasProperty('Telegram') && 
             js.context['Telegram'].hasProperty('WebApp');
    }
    return false;
  }

  static dynamic get _webApp => js.context['Telegram']['WebApp'];

  // Инициализация
  static void init() {
    if (isAvailable) {
      _webApp.callMethod('expand');
      _webApp.callMethod('ready');
    }
  }

  // Получение данных пользователя
  static Map<String, dynamic>? get user {
    if (!isAvailable) return null;
    try {
      return js.context['Telegram']['WebApp']['initDataUnsafe']['user'];
    } catch (e) {
      return null;
    }
  }

  // Получение chat_id
  static String? get chatId {
    if (!isAvailable) return null;
    try {
      return js.context['Telegram']['WebApp']['initDataUnsafe']['chat_instance'];
    } catch (e) {
      return null;
    }
  }

  // Отправка данных
  static void sendData(String data) {
    if (isAvailable) {
      _webApp.callMethod('sendData', [data]);
    }
  }

  // Закрытие приложения
  static void close() {
    if (isAvailable) {
      _webApp.callMethod('close');
    } else {
      html.window.close();
    }
  }

  // Получение темы
  static ThemeData getTheme() {
    if (!isAvailable) return ThemeData.light();

    try {
      final colorScheme = ColorScheme.light(
        primary: _parseColor(_webApp['themeParams']['button_color']),
        secondary: _parseColor(_webApp['themeParams']['link_color']),
        background: _parseColor(_webApp['themeParams']['bg_color']),
        surface: _parseColor(_webApp['themeParams']['secondary_bg_color']),
        onPrimary: _parseColor(_webApp['themeParams']['button_text_color']),
        onBackground: _parseColor(_webApp['themeParams']['text_color']),
      );

      return ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onBackground,
        ),
      );
    } catch (e) {
      return ThemeData.light();
    }
  }

  static Color _parseColor(String? color) {
    if (color == null) return Colors.white;
    return Color(int.parse(color.replaceAll('#', '0xFF')));
  }
} 