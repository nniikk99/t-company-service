import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart' as AppUserModel;
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../services/password_service.dart';
import '../services/dadata_service.dart';
import '../widgets/modern_card.dart';
import '../widgets/phone_input_field.dart';
import '../theme/app_theme.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Контроллеры полей
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyInnController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _consentToPersonalData = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Поиск организации по ИНН (DaData)
  bool _innLoading = false;
  CompanyInfo? _foundCompany;
  String? _innError;
  
  // Тип организации
  String _selectedOrgType = 'customer'; // customer | supplier | service_partner
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _companyNameController.dispose();
    _companyInnController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    return PasswordService.hashPassword(password);
  }

  /// Поиск организации по ИНН через DaData и автозаполнение названия.
  Future<void> _lookupCompanyByInn() async {
    final inn = _companyInnController.text.trim();
    if (inn.length != 10 && inn.length != 12) {
      setState(() {
        _innError = 'ИНН должен содержать 10 или 12 цифр';
        _foundCompany = null;
      });
      return;
    }
    setState(() {
      _innLoading = true;
      _innError = null;
    });
    final info = await DadataService.findByInn(inn);
    if (!mounted) return;
    setState(() {
      _innLoading = false;
      if (info == null) {
        _innError = 'Организация с таким ИНН не найдена';
        _foundCompany = null;
      } else {
        _foundCompany = info;
        _companyNameController.text = info.shortName;
      }
    });
  }

  /// Карточка найденной организации из ЕГРЮЛ.
  Widget _buildCompanyCard(CompanyInfo c) {
    final active = c.isActive;
    final statusColor =
        active ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Найдено в ЕГРЮЛ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(c.statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.shortName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          if (c.kpp != null)
            _cardRow('КПП', c.kpp!),
          if (c.ogrn != null) _cardRow('ОГРН', c.ogrn!),
          if (c.address != null && c.address!.isNotEmpty)
            _cardRow('Адрес', c.address!),
          if (c.management != null && c.management!.isNotEmpty)
            _cardRow('Руководитель', c.management!),
          if (!active) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠ Организация не действующая — проверьте ИНН',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentToPersonalData) {
      _showErrorSnackBar('Необходимо согласие на обработку персональных данных');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Проверяем, существует ли компания с таким ИНН
      String? existingCompanyId = await _findCompanyByInn(_companyInnController.text.trim());
      
      AppUserModel.UserRole userRole;
      String? companyId;
      String? companyName;

      if (existingCompanyId != null) {
        // Компания существует - пользователь ожидает одобрения
        userRole = AppUserModel.UserRole.pendingApproval;
        companyId = existingCompanyId;
        companyName = _companyNameController.text.trim();
      } else {
        // Новая компания - роль пользователя зависит от типа организации
        // Поставщик → роль supplier, остальные → companyResponsible
        userRole = _selectedOrgType == 'supplier' ? AppUserModel.UserRole.supplier : AppUserModel.UserRole.companyResponsible;
        companyId = await _createCompany();
        companyName = _companyNameController.text.trim();
      }

      // Создаем пользователя
      final user = AppUserModel.User(
        id: const Uuid().v4(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: userRole,
        position: _positionController.text.trim(),
        companyId: companyId,
        companyName: companyName,
        companyInn: _companyInnController.text.trim(),
        passwordHash: _hashPassword(_passwordController.text),
        consentToPersonalData: true,
        createdAt: DateTime.now(),
      );

      // Сохраняем пользователя в Supabase
      await SupabaseService.createUser(user);
      print('User saved to Supabase successfully');
      
      // Создаем связку с компанией в user_companies (для отображения в "Мои организации")
      final isNewCompany = existingCompanyId == null;
      try {
        await SupabaseService.requestJoinCompany(
          userId: user.id,
          companyId: companyId,
          companyInn: user.companyInn!,
          companyName: user.companyName!,
          role: isNewCompany ? 'companyResponsible' : 'siteManager', 
          status: isNewCompany ? 'approved' : 'pending',
        );
        print('Company link created successfully (status: ${isNewCompany ? 'approved' : 'pending'})');
      } catch (e) {
        print('Error creating company link: $e');
        // Не фатально, но пользователь не увидит организацию в списке сразу
      }
      
      // Освежаем данные пользователя из Supabase перед сохранением в локальное хранилище
      // Это поможет сразу подтянуть роль и компанию
      try {
        final refreshedData = await SupabaseService.getUserProfile(user.id);
        if (refreshedData != null) {
          final refreshedUser = AppUserModel.User.fromJson(refreshedData);
          await StorageService.saveUser(refreshedUser);
        } else {
          await StorageService.saveUser(user);
        }
      } catch (e) {
        print('Error refreshing user data after registration: $e');
        await StorageService.saveUser(user);
      }
      
      print('User saved to local storage successfully');

      // Показываем результат
      _showSuccessDialog(userRole == AppUserModel.UserRole.companyResponsible);

    } catch (e) {
      _showErrorSnackBar('Ошибка при регистрации: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _findCompanyByInn(String inn) async {
    try {
      return await SupabaseService.findCompanyByInn(inn);
    } catch (e) {
      print('Error finding company: $e');
      return null;
    }
  }

  Future<String> _createCompany() async {
    try {
      return await SupabaseService.createCompanyWithInn(
        name: _companyNameController.text.trim(),
        inn: _companyInnController.text.trim(),
        description: 'Автоматически создано при регистрации',
        orgType: _selectedOrgType,
      );
    } catch (e) {
      print('Error creating company: $e');
      return const Uuid().v4(); // Временный ID для локального хранения
    }
  }

  void _showSuccessDialog(bool isCompanyResponsible) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isCompanyResponsible ? Icons.admin_panel_settings : Icons.hourglass_empty,
              color: isCompanyResponsible ? Colors.green : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isCompanyResponsible ? 'Регистрация завершена!' : 'Заявка отправлена!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isCompanyResponsible 
            ? 'Вы успешно зарегистрированы как ответственное лицо компании "${_companyNameController.text.trim()}". Теперь вы можете войти в систему.'
            : 'Ваша заявка на присоединение к компании "${_companyNameController.text.trim()}" отправлена. Ожидайте одобрения от ответственного лица.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Возврат к экрану авторизации
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
        title: const Text('Регистрация'),
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
        child: SlideTransition(
          position: _slideAnimation,
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
                    
                    // Персональные данные
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 24),
                    
                    // Данные компании
                    _buildCompanyInfoSection(),
                    const SizedBox(height: 24),
                    
                    // Пароль
                    _buildPasswordSection(),
                    const SizedBox(height: 24),
                    
                    // Согласие
                    _buildConsentSection(),
                    const SizedBox(height: 32),
                    
                    // Кнопка регистрации
                    _buildRegisterButton(),
                    const SizedBox(height: 24),
                  ],
                ),
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
            Icons.person_add,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Создание аккаунта',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Заполните все поля для регистрации',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Персональные данные',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите имя';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Фамилия',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите фамилию';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Введите корректный email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          PhoneInputField(
            controller: _phoneController,
            labelText: 'Номер телефона',
            hintText: '+7 (999) 123-45-67',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите номер телефона';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _positionController,
            decoration: const InputDecoration(
              labelText: 'Должность',
              prefixIcon: Icon(Icons.work),
              hintText: 'Менеджер, Директор, и т.д.',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите должность';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Данные организации',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // ИНН первым — по нему подтянем данные организации из ЕГРЮЛ
          TextFormField(
            controller: _companyInnController,
            decoration: InputDecoration(
              labelText: 'ИНН организации',
              prefixIcon: const Icon(Icons.numbers),
              hintText: '1234567890',
              helperText: 'Введите ИНН — данные подтянутся автоматически',
              errorText: _innError,
              suffixIcon: _innLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                      tooltip: 'Найти по ИНН',
                      onPressed: _lookupCompanyByInn,
                    ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final t = v.trim();
              // Автопоиск как только введён валидный ИНН
              if (t.length == 10 || t.length == 12) {
                _lookupCompanyByInn();
              } else if (_foundCompany != null || _innError != null) {
                setState(() {
                  _foundCompany = null;
                  _innError = null;
                });
              }
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите ИНН организации';
              }
              if (value.trim().length != 10 && value.trim().length != 12) {
                return 'ИНН должен содержать 10 или 12 цифр';
              }
              return null;
            },
          ),

          // Карточка найденной организации
          if (_foundCompany != null) ...[
            const SizedBox(height: 12),
            _buildCompanyCard(_foundCompany!),
          ],

          const SizedBox(height: 16),

          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Название организации',
              prefixIcon: Icon(Icons.business),
              hintText: 'ООО "Рога и копыта"',
              helperText: 'Заполнится автоматически по ИНН (можно изменить)',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите название организации';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Тип организации
          DropdownButtonFormField<String>(
            initialValue: _selectedOrgType,
            decoration: const InputDecoration(
              labelText: 'Тип организации',
              prefixIcon: Icon(Icons.apartment),
            ),
            items: const [
              DropdownMenuItem(value: 'customer', child: Text('Заказчик')),
              DropdownMenuItem(value: 'supplier', child: Text('Поставщик')),
              DropdownMenuItem(value: 'service_partner', child: Text('Сервисный партнер')),
            ],
            onChanged: (val) => setState(() => _selectedOrgType = val ?? 'customer'),
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Если ваша организация уже зарегистрирована, вы присоединитесь к ней после одобрения ответственного лица.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Пароль',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Пароль должен содержать минимум 6 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Подтвердите пароль',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Пароли не совпадают';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConsentSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            title: const Text(
              'Согласие на обработку персональных данных',
              style: TextStyle(fontSize: 16),
            ),
            subtitle: Text(
              'Я даю согласие на обработку моих персональных данных в соответствии с политикой конфиденциальности',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: _consentToPersonalData,
            onChanged: (value) => setState(() => _consentToPersonalData = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
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
              'Зарегистрироваться',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }
}
