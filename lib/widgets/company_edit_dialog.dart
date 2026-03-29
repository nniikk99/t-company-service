import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CompanyEditDialog extends StatefulWidget {
  final Company company;
  final VoidCallback? onUpdate;

  const CompanyEditDialog({
    super.key,
    required this.company,
    this.onUpdate,
  });

  @override
  State<CompanyEditDialog> createState() => _CompanyEditDialogState();
}

class _CompanyEditDialogState extends State<CompanyEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _innController;
  late TextEditingController _kppController;
  late TextEditingController _ogrnController;
  late TextEditingController _legalAddressController;
  late TextEditingController _cityController;
  late TextEditingController _directorNameController;
  late TextEditingController _directorBasisController;
  late TextEditingController _regNumberController;
  
  late TextEditingController _bankNameController;
  late TextEditingController _bikController;
  late TextEditingController _checkAccController;
  late TextEditingController _corrAccController;
  
  String? _orgForm;
  bool _vatIncluded = false;
  bool _isSaving = false;

  final List<String> _orgForms = ['ООО', 'ИП', 'АО', 'ПАО', 'НКО'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company.name);
    _innController = TextEditingController(text: widget.company.inn);
    _kppController = TextEditingController(text: widget.company.kpp);
    _ogrnController = TextEditingController(text: widget.company.ogrn);
    _legalAddressController = TextEditingController(text: widget.company.legalAddress);
    _cityController = TextEditingController(text: widget.company.city);
    _directorNameController = TextEditingController(text: widget.company.directorName);
    _directorBasisController = TextEditingController(text: widget.company.directorBasis);
    _regNumberController = TextEditingController(text: widget.company.registrationNumber);
    
    _bankNameController = TextEditingController(text: widget.company.bankName);
    _bikController = TextEditingController(text: widget.company.bik);
    _checkAccController = TextEditingController(text: widget.company.checkingAccount);
    _corrAccController = TextEditingController(text: widget.company.correspondentAccount);
    
    _orgForm = widget.company.orgForm;
    _vatIncluded = widget.company.vatIncluded;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _innController.dispose();
    _kppController.dispose();
    _ogrnController.dispose();
    _legalAddressController.dispose();
    _cityController.dispose();
    _directorNameController.dispose();
    _directorBasisController.dispose();
    _regNumberController.dispose();
    _bankNameController.dispose();
    _bikController.dispose();
    _checkAccController.dispose();
    _corrAccController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updates = {
        'name': _nameController.text,
        'company_inn': _innController.text,
        'kpp': _kppController.text,
        'ogrn': _ogrnController.text,
        'org_form': _orgForm,
        'legal_address': _legalAddressController.text,
        'city': _cityController.text,
        'director_name': _directorNameController.text,
        'director_basis': _directorBasisController.text,
        'registration_number': _regNumberController.text,
        'bank_name': _bankNameController.text,
        'bik': _bikController.text,
        'checking_account': _checkAccController.text,
        'correspondent_account': _corrAccController.text,
        'vat_included': _vatIncluded,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.updateCompany(widget.company.id, updates);
      
      if (mounted) {
        widget.onUpdate?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Реквизиты успешно обновлены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 600,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Основные данные'),
                      _buildTextField(_nameController, 'Название организации', isRequired: true),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_innController, 'ИНН', isRequired: true, keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOrgFormDropdown()),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_kppController, 'КПП', keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(_ogrnController, 'ОГРН', keyboardType: TextInputType.number)),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      _buildSectionTitle('Адрес и город'),
                      _buildTextField(_legalAddressController, 'Юридический адрес'),
                      _buildTextField(_cityController, 'Город'),
                      
                      const SizedBox(height: 24),
                      _buildSectionTitle('Подписант'),
                      _buildTextField(_directorNameController, 'ФИО Директора / ИП'),
                      _buildTextField(_directorBasisController, 'Действует на основании', hint: 'Устава, Доверенности №...'),
                      
                      const SizedBox(height: 24),
                      _buildSectionTitle('Банковские реквизиты'),
                      _buildTextField(_bankNameController, 'Название банка', isRequired: true),
                      _buildTextField(_bikController, 'БИК', isRequired: true, keyboardType: TextInputType.number),
                      _buildTextField(_checkAccController, 'Расчетный счет (20 цифр)', isRequired: true, keyboardType: TextInputType.number),
                      _buildTextField(_corrAccController, 'Корр. счет', keyboardType: TextInputType.number),
                      
                      const SizedBox(height: 24),
                      _buildSectionTitle('Налоги'),
                      SwitchListTile(
                        title: const Text('Является плательщиком НДС'),
                        value: _vatIncluded,
                        onChanged: (val) => setState(() => _vatIncluded = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Редактирование реквизитов',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSaving 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Сохранить', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isRequired = false, TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: isRequired ? (val) => val == null || val.isEmpty ? 'Обязательное поле' : null : null,
      ),
    );
  }

  Widget _buildOrgFormDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _orgForm,
        decoration: InputDecoration(
          labelText: 'Форма',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: _orgForms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
        onChanged: (val) => setState(() => _orgForm = val),
      ),
    );
  }
}
