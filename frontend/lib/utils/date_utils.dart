import 'package:flutter/material.dart';

class DateParser {
  /// Parses a DD / MM / YYYY or DD/MM/YYYY string into a DateTime.
  /// Handles 2-digit years by assuming the last 100 years from today.
  static DateTime? parse(String text) {
    try {
      final clean = text.replaceAll(' ', '');
      final parts = clean.split('/');
      if (parts.length != 3) return null;
      
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      
      if (year < 100) {
        final now = DateTime.now();
        final currentYear = now.year;
        final currentCentury = (currentYear / 100).floor() * 100;
        final cutoff = currentYear % 100;
        
        // If the 2-digit year is <= current year's last 2 digits, assume this century
        // Otherwise, assume the previous century
        if (year <= cutoff) {
          year += currentCentury;
        } else {
          year += currentCentury - 100;
        }
      }
      
      final date = DateTime(year, month, day);
      // Basic validation (e.g. prevent 31/02/2023)
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }
}
