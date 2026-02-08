import 'package:flutter/material.dart';
import '../models/site.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/phone_input_field.dart';
import 'package:uuid/uuid.dart';

class AddSiteDialog extends StatefulWidget {
  final User user;
  final Function(Site)? onSiteAdded;

  const AddSiteDialog({
    super.key,
    required this.user,
    this.onSiteAdded,
  });

  @override
  State<AddSiteDialog> createState() => _AddSiteDialogState();
}

class _AddSiteDialogState extends State<AddSiteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _companies = [];
  String? _selectedCompanyId;
  String? _selectedCompanyInn;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    if (widget.user.canManageClients) {
      try {
        final companies = await SupabaseService.getAllCompanies();
        if (mounted) {
          setState(() {
            _companies = companies;
          });
        }
      } catch (e) {
        print('Error loading companies: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final site = Site(
        id: const Uuid().v4(),
        companyId: widget.user.companyId ?? _selectedCompanyId,
        companyInn: widget.user.companyInn ?? _selectedCompanyInn,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        contactPersonId: null, // Пока не связываем с пользователем
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Сохраняем площадку в Supabase
      await SupabaseService.createSite(site);

      // Также сохраняем локально для совместимости
      await StorageService.saveSite(site);

      if (mounted) {
        widget.onSiteAdded?.call(site);
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Площадка успешно добавлена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при добавлении площадки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Рассчитываем максимальную высоту диалога
    final maxHeight = screenHeight - keyboardHeight - 100; // 100px отступ сверху/снизу
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: screenWidth > 600 ? 500 : screenWidth - 40,
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: screenWidth > 600 ? 500 : screenWidth - 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок (фиксированный)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: _buildHeader(),
            ),
            // Основное содержимое (прокручиваемое)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              
              // Поля формы
              _buildTextField(
                controller: _nameController,
                label: 'Название площадки',
                hint: 'Введите название площадки',
                isRequired: true,
              ),
              
              const SizedBox(height: 16),

              if (widget.user.canManageClients) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Компания',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '*',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCompanyId,
                      items: _companies.map((company) {
                        return DropdownMenuItem<String>(
                          value: company['id'],
                          child: Text(company['name'] ?? 'Без названия'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCompanyId = value;
                          final selectedCompany = _companies.firstWhere((c) => c['id'] == value);
                          _selectedCompanyInn = selectedCompany['inn'] ?? selectedCompany['company_inn'];
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Выберите компанию',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      validator: (value) {
                        if (widget.user.companyId == null && value == null) {
                          return 'Выберите компанию (обязательно для админа)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
              
              _buildTextField(
                controller: _addressController,
                label: 'Точный адрес',
                hint: 'Введите точный адрес площадки',
                isRequired: true,
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _contactPersonController,
                label: 'Ответственное лицо (ФИО)',
                hint: 'Введите ФИО ответственного лица',
                isRequired: true,
              ),
              
              const SizedBox(height: 16),
              
              _buildPhoneField(
                controller: _phoneController,
                label: 'Номер телефона',
                hint: '+7 (XXX) XXX-XX-XX',
                isRequired: true,
              ),
              
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _emailController,
                label: 'Адрес электронной почты',
                hint: 'example@company.com',
                isRequired: true,
                keyboardType: TextInputType.emailAddress,
              ),
              
              const SizedBox(height: 32),
              
              // Кнопки
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Добавить площадку',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_location_alt,
                color: Color(0xFF4A90E2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Добавить новую площадку',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.grey),
              splashRadius: 20,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Заполните информацию о новой площадке для мониторинга',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isRequired,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Это поле обязательно для заполнения';
            }
            
            if (label == 'Адрес электронной почты' && value != null && value.isNotEmpty) {
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Введите корректный email адрес';
              }
            }
            
            if (label == 'Номер телефона' && value != null && value.isNotEmpty) {
              if (!RegExp(r'^[\+]?[7-8][\s\-]?\(?[0-9]{3}\)?[\s\-]?[0-9]{3}[\s\-]?[0-9]{2}[\s\-]?[0-9]{2}$').hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
                return 'Введите корректный номер телефона';
              }
            }
            
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3748),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        PhoneInputField(
          controller: controller,
          labelText: label,
          hintText: hint,
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Это поле обязательно для заполнения';
            }
            
            if (value != null && value.isNotEmpty) {
              if (!RegExp(r'^[\+]?[7-8][\s\-]?\(?[0-9]{3}\)?[\s\-]?[0-9]{3}[\s\-]?[0-9]{2}[\s\-]?[0-9]{2}$').hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
                return 'Введите корректный номер телефона';
              }
            }
            
            return null;
          },
        ),
      ],
    );
  }
}
