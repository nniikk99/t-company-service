import 'package:flutter/material.dart';
import '../models/site.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../widgets/phone_input_field.dart';

class EditSiteDialog extends StatefulWidget {
  final User currentUser;
  final Site site;
  final Function(Site)? onSiteUpdated;

  const EditSiteDialog({
    super.key,
    required this.currentUser,
    required this.site,
    this.onSiteUpdated,
  });

  @override
  State<EditSiteDialog> createState() => _EditSiteDialogState();
}

class _EditSiteDialogState extends State<EditSiteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  bool _isLoading = false;
  bool _isUsersLoading = true;
  List<User> _employees = [];
  Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.site.name);
    _addressController = TextEditingController(text: widget.site.address);
    _phoneController = TextEditingController(text: widget.site.phone);
    _emailController = TextEditingController(text: widget.site.email);
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isUsersLoading = true);
    try {
      final companyId = widget.currentUser.companyId ?? widget.site.companyId;
      final companyInn = widget.currentUser.companyInn ?? widget.site.companyInn;
      
      if (companyId != null || companyInn != null) {
        final employees = await SupabaseService.getCompanyEmployees(
          companyId: companyId,
          companyInn: companyInn,
        );
        
        // Находим всех пользователей, у которых эта площадка в списке assigned_site_ids
        final selectedIds = employees
            .where((u) => u.assignedSiteIds?.contains(widget.site.id) == true)
            .map((u) => u.id)
            .toSet();

        if (mounted) {
          setState(() {
            _employees = employees;
            _selectedUserIds = selectedIds;
            _isUsersLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading employees: $e');
      if (mounted) setState(() => _isUsersLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateSite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedSite = widget.site.copyWith(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        updatedAt: DateTime.now(),
      );

      // 1. Обновляем данные площадки в Supabase
      await SupabaseService.updateSite(updatedSite);

      // 2. Обновляем назначения ответственных
      // Мы должны пройти по всем сотрудникам компании и обновить их assigned_site_ids
      for (var employee in _employees) {
        final isSelected = _selectedUserIds.contains(employee.id);
        final wasSelected = employee.assignedSiteIds?.contains(widget.site.id) == true;

        if (isSelected && !wasSelected) {
          // Назначаем
          await SupabaseService.assignSiteToEmployee(
            employee.id, 
            widget.site.id, 
            widget.currentUser.id
          );
        } else if (!isSelected && wasSelected) {
          // Отменяем назначение
          await SupabaseService.unassignSiteFromEmployee(
            employee.id, 
            widget.site.id, 
            widget.currentUser.id
          );
        }
      }

      if (mounted) {
        widget.onSiteUpdated?.call(updatedSite);
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Площадка успешно обновлена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении площадки: $e'),
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
    
    final maxHeight = screenHeight - keyboardHeight - 60;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth > 600 ? 550 : screenWidth - 20,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  const Icon(Icons.edit_location_alt, color: Color(0xFF4A90E2), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Редактировать площадку',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(_nameController, 'Название площадки', 'Например: Склад №1', true),
                      const SizedBox(height: 16),
                      _buildTextField(_addressController, 'Адрес', 'Введите полный адрес', true),
                      const SizedBox(height: 16),
                      _buildPhoneField(_phoneController, 'Телефон', '+7 (___) ___-____', false),
                      const SizedBox(height: 16),
                      _buildTextField(_emailController, 'Email', 'example@corp.com', false, keyboardType: TextInputType.emailAddress),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Ответственные лица',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Выберите сотрудников, которые отвечают за эту площадку',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      
                      if (_isUsersLoading)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_employees.isEmpty)
                        const Text('Сотрудники не найдены', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _employees.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final employee = _employees[index];
                              final isSelected = _selectedUserIds.contains(employee.id);
                              
                              return CheckboxListTile(
                                title: Text(employee.fullName),
                                subtitle: Text(employee.roleDisplayName),
                                value: isSelected,
                                activeColor: const Color(0xFF4A90E2),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedUserIds.add(employee.id);
                                    } else {
                                      _selectedUserIds.remove(employee.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateSite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, bool isRequired, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (isRequired ? ' *' : ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (val) => isRequired && (val == null || val.isEmpty) ? 'Обязательное поле' : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(TextEditingController controller, String label, String hint, bool isRequired) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (isRequired ? ' *' : ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        PhoneInputField(
          controller: controller,
          labelText: label,
          hintText: hint,
        ),
      ],
    );
  }
}
