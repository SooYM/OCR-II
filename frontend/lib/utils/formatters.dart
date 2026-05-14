import 'package:flutter/services.dart';

/// A formatter that automatically inserts ' / ' separators for DD / MM / YYYY dates.
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), ''); // Only allow numbers
    
    if (text.length > 8) return oldValue; // Limit to DDMMYYYY
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final index = i + 1;
      if ((index == 2 || index == 4) && index != text.length) {
        buffer.write(' / ');
      }
    }
    
    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
