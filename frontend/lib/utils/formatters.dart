/// UI Text and Qualitative Value Formatters.
///
/// This module provides input formatters for dates and qualitative discrete laboratory
/// ordinal scales (e.g. Negative, Trace, 1+, 2+, 3+, Positive).
///
/// ### Simple Example:
/// ```dart
/// // Parsing discrete urine protein string into numeric ranking
/// final rank = DiscreteValueFormatter.parse('1+');
/// print(rank); // 2
/// ```
library formatters;

import 'package:flutter/services.dart';

/// A [TextInputFormatter] that automatically formats numeric keystrokes into `DD / MM / YYYY`.
class DateInputFormatter extends TextInputFormatter {
  /// Transforms unformatted numeric input into masked date strings.
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), ''); // Only allow numbers
    
    if (text.length > 8) return oldValue; // Limit to 8 digits (DDMMYYYY)
    
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

/// Formatter for discrete qualitative laboratory tests (Urinalysis dipsticks, occult blood).
class DiscreteValueFormatter {
  /// Maps a qualitative string to an integer ordinal scale (-1 for Negative, 1 for Trace, 2..4 for 1+..3+, 5 for Positive).
  ///
  /// * [value]: The qualitative string.
  /// * Returns: Integer ordinal code, or `null` if unrecognized.
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

  /// Maps an integer ordinal code back to its standardized display label.
  ///
  /// * [value]: Ordinal integer code.
  /// * Returns: Standardized string label (e.g. `'Negative'`, `'Trace'`).
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
