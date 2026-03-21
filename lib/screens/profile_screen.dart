import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/phone_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/user.dart';
import '../models/user_company.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/error_dialog.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/add_company_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final User? adminUser; // Для возврата в админ-панель
  final Function(User)? onUserUpdated; // Callback для обновления пользователя

  const ProfileScreen({
    super.key,
    required this.user,
    this.adminUser,
    this.onUserUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  bool _isEditing = false;
  bool _isLoading = false;
  List<UserCompany> _userCompanies = []; // Список всех компаний пользователя
  
  // Контроллеры для редактирования
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _commentsController = TextEditingController();
  
  // Контроллеры для информации о компании
  final _companyNameController = TextEditingController();
  final _companyInnController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  
  // Дополнительные поля профиля
  bool _isOnVacation = false;
  DateTime? _birthDate;
  String _comments = '';
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadUserData();
    _loadUserCompanies(); // Загружаем компании пользователя
  }

  Future<void> _loadUserCompanies() async {
    try {
      final companies = await SupabaseService.getApprovedUserCompanies(_currentUser.id);
      setState(() {
        _userCompanies = companies;
      });
      print('📋 Загружено компаний для пользователя: ${companies.length}');
    } catch (e) {
      print('❌ Ошибка загрузки компаний пользователя: $e');
    }
  }

  void _loadUserData() {
    _firstNameController.text = _currentUser.firstName;
    _lastNameController.text = _currentUser.lastName;
    _emailController.text = _currentUser.email;
    _phoneController.text = _currentUser.phone;
    _positionController.text = _currentUser.position;
    
    // Загружаем данные компании
    _companyNameController.text = _currentUser.companyName ?? '';
    _companyInnController.text = _currentUser.companyInn ?? '';
    _companyAddressController.text = _currentUser.companyAddress ?? '';
    _companyPhoneController.text = _currentUser.companyPhone ?? '';
    _companyEmailController.text = _currentUser.companyEmail ?? '';
    
    // Загружаем дополнительные данные из SharedPreferences
    _loadAdditionalData();
  }

  Future<void> _loadAdditionalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isOnVacation = prefs.getBool('vacation_status_${_currentUser.id}') ?? false;
        _comments = prefs.getString('user_comments_${_currentUser.id}') ?? '';
        
        // Загружаем дату рождения
        final birthDateString = prefs.getString('user_birth_date_${_currentUser.id}');
        if (birthDateString != null) {
          _birthDate = DateTime.parse(birthDateString);
          _birthDateController.text = '${_birthDate!.day.toString().padLeft(2, '0')}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.year}';
        }
      });
    } catch (e) {
      print('Error loading additional data: $e');
    }
  }

  Future<void> _saveAdditionalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vacation_status_${_currentUser.id}', _isOnVacation);
      await prefs.setString('user_comments_${_currentUser.id}', _comments);
      
      if (_birthDate != null) {
        await prefs.setString('user_birth_date_${_currentUser.id}', _birthDate!.toIso8601String());
      }
    } catch (e) {
      print('Error saving additional data: $e');
    }
  }

  Future<void> _refreshUserData() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔄 Принудительное обновление данных пользователя...');
      
      // Принудительно обновляем данные из Supabase
      final refreshedUser = await SupabaseService.forceRefreshUserData(_currentUser.id);
      
      if (refreshedUser != null) {
        setState(() {
          _currentUser = refreshedUser;
        });
        
        // Обновляем контроллеры
        _firstNameController.text = _currentUser.firstName;
        _lastNameController.text = _currentUser.lastName;
        _emailController.text = _currentUser.email;
        _phoneController.text = _currentUser.phone;
        _positionController.text = _currentUser.position;
        _companyNameController.text = _currentUser.companyName ?? '';
        _companyInnController.text = _currentUser.companyInn ?? '';
        _companyAddressController.text = _currentUser.companyAddress ?? '';
        
        // Уведомляем родительский виджет об обновлении
        if (widget.onUserUpdated != null) {
          widget.onUserUpdated!(_currentUser);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Данные обновлены! Назначенные площадки: ${_currentUser.assignedSiteIds?.length ?? 0}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        print('✅ Данные пользователя успешно обновлены');
        print('🔍 Назначенные площадки: ${_currentUser.assignedSiteIds}');
      } else {
        throw Exception('Не удалось загрузить данные пользователя');
      }
    } catch (e) {
      print('❌ Ошибка обновления данных пользователя: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка обновления данных: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveVacationStatus(bool isOnVacation) async {
    try {
      // Сохраняем в Supabase
      await SupabaseService.updateUserProfile(
        userId: _currentUser.id,
        isOnVacation: isOnVacation,
      );
      print('✅ Статус отпуска обновлен в Supabase: $isOnVacation');
    } catch (e) {
      print('⚠️ Ошибка обновления статуса отпуска в Supabase: $e');
    }
    
    // Сохраняем статус отпуска в SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vacation_status_${_currentUser.id}', isOnVacation);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnVacation ? '🏖️ Статус: В отпуске' : '💼 Статус: На работе'),
          backgroundColor: isOnVacation ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool _validateForm() {
    if (_firstNameController.text.trim().isEmpty) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Поле "Имя" обязательно для заполнения',
      );
      return false;
    }
    
    if (_lastNameController.text.trim().isEmpty) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Поле "Фамилия" обязательно для заполнения',
      );
      return false;
    }
    
    if (_emailController.text.trim().isEmpty) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Поле "Email" обязательно для заполнения',
      );
      return false;
    }
    
    if (_phoneController.text.trim().isEmpty) {
      ErrorDialog.show(
        context: context,
        title: 'Ошибка',
        message: 'Поле "Телефон" обязательно для заполнения',
      );
      return false;
    }
    
    return true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Фото профиля обновлено'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showAddCompanyDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCompanyDialog(
        user: _currentUser,
        onCompanyAdded: () {
          // Обновляем данные пользователя после добавления компании
          _loadUserData();
          _loadUserCompanies(); // Перезагружаем список компаний
          if (widget.onUserUpdated != null) {
            widget.onUserUpdated!(_currentUser);
          }
        },
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_validateForm()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Обновляем основные данные пользователя
      final updatedUser = _currentUser.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        position: _positionController.text.trim(),
        // Обновляем данные компании
        companyName: _companyNameController.text.trim().isNotEmpty ? _companyNameController.text.trim() : null,
        companyInn: _companyInnController.text.trim().isNotEmpty ? _companyInnController.text.trim() : null,
        companyAddress: _companyAddressController.text.trim().isNotEmpty ? _companyAddressController.text.trim() : null,
        companyPhone: _companyPhoneController.text.trim().isNotEmpty ? _companyPhoneController.text.trim() : null,
        companyEmail: _companyEmailController.text.trim().isNotEmpty ? _companyEmailController.text.trim() : null,
      );
      
      // Сохраняем в Supabase (если подключено)
      try {
        await SupabaseService.updateUserProfile(
          userId: updatedUser.id,
          firstName: updatedUser.firstName,
          lastName: updatedUser.lastName,
          email: updatedUser.email,
          phone: updatedUser.phone,
          position: updatedUser.position,
          companyName: updatedUser.companyName,
          companyInn: updatedUser.companyInn,
          companyAddress: updatedUser.companyAddress,
          companyPhone: updatedUser.companyPhone,
          companyEmail: updatedUser.companyEmail,
          birthDate: _birthDate,
          comments: _comments,
          isOnVacation: _isOnVacation,
        );
        print('✅ Профиль успешно обновлен в Supabase');
      } catch (e) {
        print('⚠️ Ошибка обновления в Supabase: $e');
        // Продолжаем с локальным сохранением
      }
      
      // Сохраняем в локальное хранилище (всегда)
      await StorageService.saveUser(updatedUser);
      
      // ВАЖНО: Обновляем текущего пользователя в системе
      await StorageService.setCurrentUser(updatedUser);
      
      // Сохраняем дополнительные данные
      await _saveAdditionalData();
      
      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
        _isLoading = false;
      });
      
      // Вызываем callback для обновления пользователя в родительском виджете
      if (widget.onUserUpdated != null) {
        widget.onUserUpdated!(updatedUser);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Профиль успешно обновлен'),
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
          message: 'Не удалось сохранить профиль: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        leading: widget.adminUser != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Мой профиль',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _refreshUserData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Обновить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A745),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Редактировать'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Отмена'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label: Text(_isLoading ? 'Сохранение...' : 'Сохранить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Фото профиля
            _buildProfilePhoto(),
            
            const SizedBox(height: 24),
            
            // Статус "В отпуске"
            _buildVacationStatus(),
            
            const SizedBox(height: 24),
            
            // Основная информация
            _buildBasicInfo(),
            
            const SizedBox(height: 24),
            
            // Информация о компании
            _buildCompanyInfo(),
            
            const SizedBox(height: 24),
            
            // Дополнительная информация
            _buildAdditionalInfo(),
            
            const SizedBox(height: 24),
            
            // Кнопка смены пароля
            _buildChangePasswordButton(),
            
            const SizedBox(height: 100), // Отступ снизу
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 3),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[200],
              backgroundImage: _profileImage != null
                  ? FileImage(_profileImage!)
                  : null,
              child: _profileImage == null
                  ? Text(
                      '${_currentUser.firstName[0]}${_currentUser.lastName[0]}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A90E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVacationStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.beach_access,
            color: _isOnVacation ? Colors.orange : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'В отпуске',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isOnVacation ? Colors.orange : Colors.black87,
                  ),
                ),
                Text(
                  _isOnVacation ? 'Сотрудник в отпуске' : 'Сотрудник на работе',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isOnVacation,
            onChanged: (value) {
              setState(() {
                _isOnVacation = value;
              });
              _saveVacationStatus(value);
            },
            activeThumbColor: Colors.orange,
            activeTrackColor: Colors.orange.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.person,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Основная информация',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Имя',
            controller: _firstNameController,
            icon: Icons.person_outline,
            enabled: _isEditing,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Фамилия',
            controller: _lastNameController,
            icon: Icons.person_outline,
            enabled: _isEditing,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Email',
            controller: _emailController,
            icon: Icons.email_outlined,
            enabled: _isEditing,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Телефон',
            controller: _phoneController,
            icon: Icons.phone,
            enabled: _isEditing,
            isPhone: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Должность',
            controller: _positionController,
            icon: Icons.work,
            enabled: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfo() {
    // Если пользователь не ответственное лицо - показываем старый дизайн
    if (_currentUser.role != UserRole.companyResponsible) {
      return _buildSingleCompanyInfo();
    }
    
    // Для ответственных лиц - новый дизайн с несколькими компаниями
    return Column(
      children: [
        // Заголовок с кнопкой добавления
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.business,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Мои компании',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_currentUser.canManageCompany)
                GestureDetector(
                  onTap: _showAddCompanyDialog,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Список компаний
        ...(_userCompanies.map((company) => _buildCompanyCard(company)).toList()),
        
        // Если нет компаний, показываем основную компанию из профиля
        if (_userCompanies.isEmpty) _buildMainCompanyCard(),
      ],
    );
  }

  Widget _buildSingleCompanyInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.business,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Информация о компании',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Название компании',
            controller: _companyNameController,
            icon: Icons.business_outlined,
            enabled: _isEditing,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'ИНН',
            controller: _companyInnController,
            icon: Icons.credit_card,
            enabled: _isEditing,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Адрес компании',
            controller: _companyAddressController,
            icon: Icons.location_on,
            enabled: _isEditing,
            maxLines: 2,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Телефон компании',
            controller: _companyPhoneController,
            icon: Icons.phone_outlined,
            enabled: _isEditing,
            isPhone: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Email компании',
            controller: _companyEmailController,
            icon: Icons.email_outlined,
            enabled: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(UserCompany company) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.business_outlined,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  company.companyName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  company.role == 'companyResponsible' ? 'Ответственный' : company.role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          _buildCompanyField('ИНН', company.companyInn, Icons.credit_card),
          const SizedBox(height: 8),
          _buildCompanyField('Статус', company.status == 'approved' ? 'Одобрено' : company.status, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildMainCompanyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.business_outlined,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentUser.companyName ?? 'Основная компания',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Основная',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          _buildCompanyField('ИНН', _currentUser.companyInn ?? '', Icons.credit_card),
          const SizedBox(height: 8),
          _buildCompanyField('Адрес', _currentUser.companyAddress ?? '', Icons.location_on),
          const SizedBox(height: 8),
          _buildCompanyField('Телефон', _currentUser.companyPhone ?? '', Icons.phone_outlined),
          const SizedBox(height: 8),
          _buildCompanyField('Email', _currentUser.companyEmail ?? '', Icons.email_outlined),
        ],
      ),
    );
  }

  Widget _buildCompanyField(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF4A90E2),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Дополнительная информация',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Дата рождения',
            controller: _birthDateController,
            icon: Icons.cake_outlined,
            enabled: _isEditing,
            readOnly: true,
            onTap: _isEditing ? _selectBirthDate : null,
          ),
          
          const SizedBox(height: 16),
          
          _buildInfoField(
            label: 'Комментарии о себе',
            controller: _commentsController,
            icon: Icons.comment_outlined,
            enabled: _isEditing,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = false,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF4A90E2) : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          maxLines: maxLines,
          onTap: onTap,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          inputFormatters: isPhone ? [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
            PhoneInputFormatter(),
          ] : null,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: enabled ? const Color(0xFF4A90E2) : Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePasswordButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline,
            color: Color(0xFF4A90E2),
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Безопасность',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Изменить пароль для входа в систему',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ChangePasswordDialog(
                  userPhone: _currentUser.phone,
                ),
              );
            },
            icon: const Icon(Icons.key, size: 18),
            label: const Text('Изменить пароль'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.administrator:
        return Colors.purple;
      case UserRole.companyResponsible:
        return Colors.blue;
      case UserRole.siteManager:
        return Colors.green;
      case UserRole.operatorPM:
        return Colors.orange;
      case UserRole.pendingApproval:
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _birthDateController.dispose();
    _commentsController.dispose();
    
    // Освобождаем контроллеры компании
    _companyNameController.dispose();
    _companyInnController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    
    super.dispose();
  }
}