import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';

class UserProvider with ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCurrentUser() async {
    _setLoading(true);
    _clearError();

    try {
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser != null) {
        final user = await SupabaseService.getUserById(supabaseUser.id);
        _currentUser = user;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUser(AppUser user) async {
    _setLoading(true);
    _clearError();

    try {
      // Здесь будет логика обновления пользователя
      _currentUser = user;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
