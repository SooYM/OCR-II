import 'package:flutter/material.dart';

class DateParser {
  /// Parses a DD / MM / YYYY or DD/MM/YYYY string into a DateTime.
  /// Handles 2-digit years by assuming the last 100 years from today.
  static DateTime? parse(String text) {
    try {
      // 1. Normalize separators and strip time
      // First, handle " / " spacing
      String normalized = text.trim()
          .replaceAll(' / ', '/')
          .replaceAll(' - ', '-')
          .replaceAll(' . ', '.');
      
      // If there is still a space, it separates Date from Time (e.g. 26/08/2018 07:01:00)
      if (normalized.contains(' ')) {
        normalized = normalized.split(' ')[0];
      }
      
      final clean = normalized;
      
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
