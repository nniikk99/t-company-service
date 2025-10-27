import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.validator,
    this.onChanged,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_formatPhoneNumber);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_formatPhoneNumber);
    super.dispose();
  }

  void _formatPhoneNumber() {
    final text = widget.controller.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    String formatted = '';
    if (digitsOnly.isNotEmpty) {
      if (digitsOnly.startsWith('7') || digitsOnly.startsWith('8')) {
        // Российский номер: +7 (981) 746-73-95
        String cleanDigits = digitsOnly.substring(digitsOnly.startsWith('8') ? 1 : 1);
        
        if (cleanDigits.isEmpty) {
          formatted = '+7';
        } else if (cleanDigits.length <= 3) {
          formatted = '+7 ($cleanDigits';
        } else if (cleanDigits.length <= 6) {
          formatted = '+7 (${cleanDigits.substring(0, 3)}) ${cleanDigits.substring(3)}';
        } else if (cleanDigits.length <= 8) {
          formatted = '+7 (${cleanDigits.substring(0, 3)}) ${cleanDigits.substring(3, 6)}-${cleanDigits.substring(6)}';
        } else {
          formatted = '+7 (${cleanDigits.substring(0, 3)}) ${cleanDigits.substring(3, 6)}-${cleanDigits.substring(6, 8)}-${cleanDigits.substring(8)}';
        }
      } else if (digitsOnly.startsWith('9') || digitsOnly.length > 10) {
        // Номер начинается с 9 (скорее всего это 10 цифр без +7)
        String cleanDigits = digitsOnly;
        
        if (cleanDigits.length <= 3) {
          formatted = '+7 ($cleanDigits';
        } else if (cleanDigits.length <= 6) {
          formatted = '+7 (${cleanDigits.substring(0, 3)}) ${cleanDigits.substring(3)}';
        } else if (cleanDigits.length <= 8) {
          formatted = '+7 (${cleanDigits.substring(0, 3)}) ${cleanDigits.substring(3, 6)}-${cleanDigits.substring(6)}';
        } else {
          formatted = '+7 (${cleanDigits.substring(0, 3)}) ${cleanDigits.substring(3, 6)}-${cleanDigits.substring(6, 8)}-${cleanDigits.substring(8)}';
        }
      } else {
        // Простое форматирование для других номеров
        formatted = digitsOnly;
      }
    }

    if (formatted != text) {
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\s\(\)\+\-]')),
        LengthLimitingTextInputFormatter(18), // Максимальная длина форматированного номера
      ],
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Colors.black87),
        floatingLabelStyle: const TextStyle(color: Colors.black87),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
      ),
      validator: widget.validator,
      onChanged: widget.onChanged,
    );
  }
}
