import 'package:flutter/material.dart';
import '../services/telegram_service.dart';

class TelegramBindScreen extends StatefulWidget {
  @override
  _TelegramBindScreenState createState() => _TelegramBindScreenState();
}

class _TelegramBindScreenState extends State<TelegramBindScreen> {
  final _botUsernameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _bindTelegram() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Здесь будет логика привязки
      // Пока просто имитация
      await Future.delayed(Duration(seconds: 2));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Telegram успешно привязан!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка привязки Telegram: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Привязка Telegram'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Для привязки Telegram:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            Text(
              '1. Найдите нашего бота: @t_company_bot\n'
              '2. Отправьте команду /start\n'
              '3. Введите код привязки:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 24),
            TextField(
              controller: _botUsernameController,
              decoration: InputDecoration(
                labelText: 'Код привязки',
                helperText: 'Введите код, который вы получили от бота',
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _bindTelegram,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Привязать Telegram'),
            ),
          ],
        ),
      ),
    );
  }
} 