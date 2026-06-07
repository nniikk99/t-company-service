import 'package:supabase_flutter/supabase_flutter.dart';

/// Подтверждение email через Edge Function `email-verification`.
class EmailVerificationService {
  static final _client = Supabase.instance.client;

  /// Отправить 6-значный код на указанный email.
  /// Возвращает null при успехе, либо текст ошибки.
  static Future<String?> sendCode(String email) async {
    try {
      final res = await _client.functions.invoke(
        'email-verification',
        body: {'action': 'send', 'email': email.trim()},
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) return null;
      if (data is Map && data['error'] != null) return data['error'].toString();
      return 'Не удалось отправить код';
    } catch (e) {
      return 'Ошибка отправки: $e';
    }
  }

  /// Проверить код. Возвращает true если подтверждён.
  /// errorOut — текст ошибки (если есть).
  static Future<({bool verified, String? error})> verifyCode(
      String email, String code) async {
    try {
      final res = await _client.functions.invoke(
        'email-verification',
        body: {
          'action': 'verify',
          'email': email.trim(),
          'code': code.trim(),
        },
      );
      final data = res.data;
      if (data is Map) {
        return (
          verified: data['verified'] == true,
          error: data['error']?.toString(),
        );
      }
      return (verified: false, error: 'Неожиданный ответ сервера');
    } catch (e) {
      return (verified: false, error: 'Ошибка проверки: $e');
    }
  }
}
