import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../widgets/modern_card.dart';
import '../theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  final User user;
  
  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Проверяем текущий пароль
      final currentPasswordHash = _hashPassword(_currentPasswordController.text);
      if (currentPasswordHash != widget.user.passwordHash) {
        _showErrorSnackBar('Неверный текущий пароль');
        return;
      }

      // Хэшируем новый пароль
      final newPasswordHash = _hashPassword(_newPasswordController.text);

      // Обновляем пароль в Supabase
      try {
        await SupabaseService.changePassword(widget.user.id, newPasswordHash);
      } catch (e) {
        print('Supabase error: $e');
        // Продолжаем с локальным обновлением
      }

      // Обновляем пароль локально
      final updatedUser = widget.user.copyWith(
        passwordHash: newPasswordHash,
        updatedAt: DateTime.now(),
      );
      await StorageService.saveUser(updatedUser);

      _showSuccessDialog();

    } catch (e) {
      _showErrorSnackBar('Ошибка при смене пароля: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Пароль изменен!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Ваш пароль успешно изменен. При следующем входе используйте новый пароль.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Возврат к предыдущему экрану
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Смена пароля'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Заголовок
                  _buildHeader(),
                  const SizedBox(height: 32),
                  
                  // Форма смены пароля
                  _buildPasswordForm(),
                  const SizedBox(height: 32),
                  
                  // Кнопка сохранения
                  _buildSaveButton(),
                  const SizedBox(height: 24),
                  
                  // Информация о безопасности
                  _buildSecurityInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.lock_reset,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Привет, ${widget.user.firstName}!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Измените свой пароль для повышения безопасности',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Смена пароля',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Текущий пароль
          TextFormField(
            controller: _currentPasswordController,
            decoration: InputDecoration(
              labelText: 'Текущий пароль',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
              ),
            ),
            obscureText: _obscureCurrentPassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите текущий пароль';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Новый пароль
          TextFormField(
            controller: _newPasswordController,
            decoration: InputDecoration(
              labelText: 'Новый пароль',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
            obscureText: _obscureNewPassword,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Новый пароль должен содержать минимум 6 символов';
              }
              if (value == _currentPasswordController.text) {
                return 'Новый пароль должен отличаться от текущего';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Подтверждение нового пароля
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Подтвердите новый пароль',
              prefixIcon: const Icon(Icons.lock_clock),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (value != _newPasswordController.text) {
                return 'Пароли не совпадают';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _changePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Изменить пароль',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.blue[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Рекомендации по безопасности',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSecurityTip('Используйте минимум 8 символов'),
          _buildSecurityTip('Включите заглавные и строчные буквы'),
          _buildSecurityTip('Добавьте цифры и специальные символы'),
          _buildSecurityTip('Не используйте личную информацию'),
          _buildSecurityTip('Регулярно меняйте пароль'),
        ],
      ),
    );
  }

  Widget _buildSecurityTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green[600],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
