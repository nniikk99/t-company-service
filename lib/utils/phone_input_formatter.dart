import 'package:flutter/services.dart';

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String formattedText = '+7';
    int digitIndex = 0;

    if (digitsOnly.length > 0) {
      // Skip initial '7' if present, as we add '+7' manually
      if (digitsOnly[0] == '7' && digitsOnly.length > 1) {
        digitIndex = 1;
      } else if (digitsOnly[0] == '8') {
        digitIndex = 1;
      }
    }

    // (XXX) XXX-XX-XX
    if (digitsOnly.length - digitIndex > 0) {
      formattedText += ' (' + digitsOnly.substring(digitIndex, (digitIndex + 3).clamp(0, digitsOnly.length));
      if (digitsOnly.length - digitIndex > 3) {
        formattedText += ') ' + digitsOnly.substring((digitIndex + 3).clamp(0, digitsOnly.length), (digitIndex + 6).clamp(0, digitsOnly.length));
        if (digitsOnly.length - digitIndex > 6) {
          formattedText += '-' + digitsOnly.substring((digitIndex + 6).clamp(0, digitsOnly.length), (digitIndex + 8).clamp(0, digitsOnly.length));
          if (digitsOnly.length - digitIndex > 8) {
            formattedText += '-' + digitsOnly.substring((digitIndex + 8).clamp(0, digitsOnly.length), (digitIndex + 10).clamp(0, digitsOnly.length));
          }
        }
      }
    }

    // Adjust cursor position
    int newSelectionStart = newValue.selection.end + (formattedText.length - oldValue.text.length);
    if (newSelectionStart < 0) newSelectionStart = 0;
    if (newSelectionStart > formattedText.length) newSelectionStart = formattedText.length;

    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newSelectionStart),
    );
  }
}
