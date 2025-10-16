import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

/// Централизованный сервис для работы с паролями
class PasswordService {
  // Соль для дополнительной безопасности
  static const String _salt = 't_co_service_2024_salt';

  /// Хеширование пароля с использованием SHA-256 и соли
  static String hashPassword(String password) {
    var bytes = utf8.encode(password + _salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Проверка пароля
  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }

  /// Генерация случайного пароля
  static String generateRandomPassword({int length = 8}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var random = Random();
    var password = '';
    
    for (int i = 0; i < length; i++) {
      password += chars[random.nextInt(chars.length)];
    }
    
    return password;
  }

  /// Генерация кода восстановления (6 цифр)
  static String generateRecoveryCode() {
    var random = Random();
    var code = '';
    for (int i = 0; i < 6; i++) {
      code += random.nextInt(10).toString();
    }
    return code;
  }

  /// Проверка сложности пароля
  static PasswordStrength checkPasswordStrength(String password) {
    int score = 0;
    
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;
    
    if (score < 2) return PasswordStrength.weak;
    if (score < 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// Получить описание сложности пароля
  static String getPasswordStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Слабый пароль';
      case PasswordStrength.medium:
        return 'Средний пароль';
      case PasswordStrength.strong:
        return 'Надежный пароль';
    }
  }

  /// Получить цвет для индикатора сложности
  static int getPasswordStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 0xFFFF5252; // Красный
      case PasswordStrength.medium:
        return 0xFFFF9800; // Оранжевый
      case PasswordStrength.strong:
        return 0xFF4CAF50; // Зеленый
    }
  }
}

enum PasswordStrength {
  weak,
  medium,
  strong,
}
