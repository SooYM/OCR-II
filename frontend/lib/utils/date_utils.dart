import 'package:flutter/material.dart';

class DateParser {
  /// Parses a DD / MM / YYYY or DD/MM/YYYY string into a DateTime.
  /// Handles 2-digit years by assuming the last 100 years from today.
  static DateTime? parse(String text) {
    try {
      final clean = text.replaceAll(' ', '');
      
      // Try YYYY-MM-DD format (often from LLM/OCR)
      if (clean.contains('-')) {
        final parts = clean.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else if (parts[2].length == 4) {
            // DD-MM-YYYY
            return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      }

      // Try DD/MM/YYYY or DD.MM.YYYY
      final separator = clean.contains('/') ? '/' : '.';
      final parts = clean.split(separator);
      if (parts.length != 3) return null;
      
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      
      if (year < 100) {
        final now = DateTime.now();
        final currentYear = now.year;
        final currentCentury = (currentYear / 100).floor() * 100;
        final cutoff = currentYear % 100;
        
        if (year <= cutoff) {
          year += currentCentury;
        } else {
          year += currentCentury - 100;
        }
      }
      
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }
}
