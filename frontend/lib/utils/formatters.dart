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

class DiscreteValueFormatter {
  static int? parse(String value) {
    final v = value.toLowerCase().trim();
    if (v == 'negative' || v == 'neg' || v == 'nil' || v == 'clear') return -1;
    if (v == 'trace' || v == 'slight') return 1;
    if (v == '1+' || v == '+1' || v == '+') return 2;
    if (v == '2+' || v == '+2' || v == '++') return 3;
    if (v == '3+' || v == '+3' || v == '+++' || v == '4+' || v == '+4' || v == '++++') return 4;
    if (v == 'positive' || v == 'pos' || v == 'cloudy') return 5;
    return null;
  }

  static String format(int value) {
    switch (value) {
      case -1: return 'Negative';
      case 1: return 'Trace';
      case 2: return '1+';
      case 3: return '2+';
      case 4: return '3+';
      case 5: return 'Positive';
      default: return '';
    }
  }
}
