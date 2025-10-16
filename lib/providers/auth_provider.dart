import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  Future<bool> signIn(String phone, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Здесь должна быть логика входа по телефону
      // Пока используем заглушку
      await Future.delayed(const Duration(seconds: 1));
      
      // В реальном приложении здесь будет вызов Supabase
      // final response = await Supabase.instance.client.auth.signInWithPassword(
      //   email: email,
      //   password: password,
      // );
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp(String phone, String password, String firstName, String lastName) async {
    _setLoading(true);
    _clearError();

    try {
      // Здесь должна быть логика регистрации
      await Future.delayed(const Duration(seconds: 1));
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
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
