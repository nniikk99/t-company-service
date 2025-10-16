import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Аутентификация
  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static User? get currentUser {
    return _client.auth.currentUser;
  }

  // Работа с пользователями
  static Future<List<AppUser>> getUsers() async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => AppUser.fromJson(json))
        .toList();
  }

  static Future<AppUser?> getUserById(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return AppUser.fromJson(response);
  }

  // Уведомления
  static Future<void> createNotification({
    required String title,
    required String message,
    String? userId,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId ?? currentUser?.id,
      'title': title,
      'message': message,
      'is_read': false,
    });
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', currentUser?.id ?? '')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }
}
