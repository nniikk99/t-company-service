import 'package:flutter/material.dart';
import '../services/password_service.dart';
import '../widgets/error_dialog.dart';

class ChangePasswordDialog extends StatefulWidget {
  final String userPhone;

  const ChangePasswordDialog({
    super.key,
    required this.userPhone,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _showForgotPassword = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Смена пароля'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_showForgotPassword) ...[
              // Текущий пароль
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Текущий пароль',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Новый пароль
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'Новый пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Подтверждение пароля
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Подтвердите новый пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Кнопка "Забыли пароль?"
              TextButton(
                onPressed: () => setState(() => _showForgotPassword = true),
                child: const Text('Забыли пароль?'),
              ),
            ] else ...[
              // Восстановление через Telegram
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.telegram, color: Colors.blue, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Восстановление пароля через Telegram',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'На номер ${widget.userPhone} будет отправлен код подтверждения для смены пароля',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _sendRecoveryCode,
                      icon: const Icon(Icons.send),
                      label: const Text('Отправить код'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => setState(() => _showForgotPassword = false),
                child: const Text('Вернуться к смене пароля'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_showForgotPassword) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Изменить'),
          ),
        ],
      ],
    );
  }

  Future<void> _changePassword() async {
    if (!_validatePasswordForm()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Здесь должна быть проверка текущего пароля
      // Пока просто сохраняем новый пароль
      final hashedPassword = PasswordService.hashPassword(_newPasswordController.text);
      
      // TODO: Обновить пароль в базе данных
      // await SupabaseService.updateUserPassword(widget.userPhone, hashedPassword);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Пароль успешно изменен'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorDialog.show(
          context: context,
          title: 'Ошибка',
          message: 'Не удалось изменить пароль: $e',
        );
      }
    }
  }

  Future<void> _sendRecoveryCode() async {
    setState(() => _isLoading = true);
    
    try {
      // TODO: Реализовать отправку кода восстановления
      // await TelegramBotService.sendPasswordRecoveryCode(widget.userPhone);
      print('Telegram recovery code not implemented yet');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Код отправлен в Telegram (заглушка)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorDialog.show(
          context: context,
          title: 'Ошибка',
          message: 'Не удалось отправить код: $e',
        );
      }
    }
  }

  bool _validatePasswordForm() {
    if (_currentPasswordController.text.isEmpty) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Введите текущий пароль',
      );
      return false;
    }
    
    if (_newPasswordController.text.isEmpty) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Введите новый пароль',
      );
      return false;
    }
    
    if (_newPasswordController.text.length < 6) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Пароль должен содержать минимум 6 символов',
      );
      return false;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Пароли не совпадают',
      );
      return false;
    }
    
    return true;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
