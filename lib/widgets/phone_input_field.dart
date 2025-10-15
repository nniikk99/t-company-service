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
      if (digitsOnly.startsWith('7')) {
        // Российский номер: +7 (999) 123-45-67
        if (digitsOnly.length >= 1) {
          formatted = '+7';
        }
        if (digitsOnly.length >= 2) {
          formatted += ' (${digitsOnly.substring(1, digitsOnly.length > 4 ? 4 : digitsOnly.length)}';
        }
        if (digitsOnly.length >= 5) {
          formatted += ') ${digitsOnly.substring(4, digitsOnly.length > 7 ? 7 : digitsOnly.length)}';
        }
        if (digitsOnly.length >= 8) {
          formatted += '-${digitsOnly.substring(7, digitsOnly.length > 9 ? 9 : digitsOnly.length)}';
        }
        if (digitsOnly.length >= 10) {
          formatted += '-${digitsOnly.substring(9, digitsOnly.length > 11 ? 11 : digitsOnly.length)}';
        }
      } else if (digitsOnly.startsWith('8')) {
        // Альтернативный формат: 8 (999) 123-45-67
        if (digitsOnly.length >= 1) {
          formatted = '8';
        }
        if (digitsOnly.length >= 2) {
          formatted += ' (${digitsOnly.substring(1, digitsOnly.length > 4 ? 4 : digitsOnly.length)}';
        }
        if (digitsOnly.length >= 5) {
          formatted += ') ${digitsOnly.substring(4, digitsOnly.length > 7 ? 7 : digitsOnly.length)}';
        }
        if (digitsOnly.length >= 8) {
          formatted += '-${digitsOnly.substring(7, digitsOnly.length > 9 ? 9 : digitsOnly.length)}';
        }
        if (digitsOnly.length >= 10) {
          formatted += '-${digitsOnly.substring(9, digitsOnly.length > 11 ? 11 : digitsOnly.length)}';
        }
      } else {
        // Простое форматирование для других номеров
        formatted = digitsOnly;
      }
    }

    if (formatted != text) {
      widget.controller.value = widget.controller.value.copyWith(
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
