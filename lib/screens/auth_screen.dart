import 'package:flutter/material.dart';
import '../services/n8n_service.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _innController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Тестовые данные
  final List<String> _testInns = ['1234567890', '0987654321'];

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await N8nService.registerUser(
        inn: _innController.text,
        email: _emailController.text,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Регистрация успешна! Пароль будет отправлен менеджеру.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка регистрации. Попробуйте позже.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Регистрация')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _innController,
                decoration: InputDecoration(
                  labelText: 'ИНН компании',
                  helperText: 'Тестовые ИНН: ${_testInns.join(", ")}',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Введите ИНН';
                  if (!_testInns.contains(value)) return 'ИНН не найден в базе';
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Введите email';
                  if (!value!.contains('@')) return 'Введите корректный email';
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading ? CircularProgressIndicator() : Text('Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 