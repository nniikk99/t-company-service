import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart' as AppUserModel;
import '../services/supabase_service.dart';

class AddCompanyDialog extends StatefulWidget {
  final AppUserModel.User user;
  final Function()? onCompanyAdded;

  const AddCompanyDialog({
    super.key,
    required this.user,
    this.onCompanyAdded,
  });

  @override
  State<AddCompanyDialog> createState() => _AddCompanyDialogState();
}

class _AddCompanyDialogState extends State<AddCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _innController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Роль всегда companyResponsible для дополнительных компаний
  String _selectedOrgType = 'customer'; // customer | supplier | service_partner
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _existingCompany;

  @override
  void dispose() {
    _innController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkCompanyExists() async {
    if (_innController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _existingCompany = null;
    });

    try {
      final company = await SupabaseService.findCompanyByInnFull(_innController.text);
      if (company != null) {
        setState(() {
          _existingCompany = company;
          _nameController.text = company['name'] ?? '';
          _addressController.text = company['address'] ?? '';
          _phoneController.text = company['contact_phone'] ?? '';
          _emailController.text = company['contact_email'] ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка проверки компании: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_existingCompany != null) {
        // Присоединение к существующей компании
        final isAssigned = await SupabaseService.isCompanyResponsibleAssigned(_existingCompany!['id']);
        if (isAssigned) {
          setState(() {
            _errorMessage = 'В этой компании уже есть ответственное лицо';
          });
          return;
        }

        await SupabaseService.requestJoinCompany(
          userId: widget.user.id,
          companyId: _existingCompany!['id'],
          companyInn: _innController.text,
          companyName: _nameController.text,
          role: 'companyResponsible',
        );
      } else {
        // Создание новой компании
        await SupabaseService.requestCreateCompany(
          userId: widget.user.id,
          companyName: _nameController.text,
          companyInn: _innController.text,
          companyAddress: _addressController.text,
          companyPhone: _phoneController.text,
          companyEmail: _emailController.text,
          requestedRole: 'companyResponsible',
          orgType: _selectedOrgType,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingCompany != null 
                ? 'Заявка на присоединение к компании в качестве ответственного лица отправлена'
                : 'Заявка на создание компании с вами в качестве ответственного лица отправлена'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        widget.onCompanyAdded?.call();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка отправки заявки: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.business, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Добавить компанию',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ИНН компании
              TextFormField(
                controller: _innController,
                decoration: const InputDecoration(
                  labelText: 'ИНН компании *',
                  hintText: 'Введите ИНН компании',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите ИНН компании';
                  }
                  if (value.length < 10 || value.length > 12) {
                    return 'ИНН должен содержать 10-12 цифр';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.length >= 10) {
                    _checkCompanyExists();
                  }
                },
              ),
              const SizedBox(height: 16),

              // Индикатор проверки компании
              if (_isLoading)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Проверяем компанию...'),
                  ],
                )
              else if (_existingCompany != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Компания найдена в системе. Будет создана заявка на присоединение в качестве ответственного лица.',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_innController.text.length >= 10)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Компания не найдена. Будет создана новая компания с вами в качестве ответственного лица.',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Название компании
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название компании *',
                  hintText: 'Введите название компании',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите название компании';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Адрес компании
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Адрес компании',
                  hintText: 'Введите адрес компании',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Телефон компании
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Телефон компании',
                  hintText: 'Введите телефон компании',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Email компании
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email компании',
                  hintText: 'Введите email компании',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Введите корректный email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Тип организации (только для новых компаний)
              if (_existingCompany == null)
                DropdownButtonFormField<String>(
                  initialValue: _selectedOrgType,
                  decoration: const InputDecoration(
                    labelText: 'Тип организации',
                    prefixIcon: Icon(Icons.apartment),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'customer',
                      child: Text('🏢 Заказчик'),
                    ),
                    DropdownMenuItem(
                      value: 'supplier',
                      child: Text('📦 Поставщик'),
                    ),
                    DropdownMenuItem(
                      value: 'service_partner',
                      child: Text('🔧 Сервисный партнер'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedOrgType = value;
                      });
                    }
                  },
                ),
              
              if (_existingCompany == null) const SizedBox(height: 16),

              // Информационное сообщение о типе организации
              if (_existingCompany == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Выберите тип организации: заказчик получает услуги, поставщик продаёт товары, сервисный партнёр оказывает услуги.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),

              // Ошибка
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) const SizedBox(height: 16),

              // Кнопки
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Отправить заявку'),
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
