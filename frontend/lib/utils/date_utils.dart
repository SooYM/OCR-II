/// Clinical Date Parser & Normalization Engine.
///
/// This module parses ambiguous, multi-format date strings extracted from
/// medical laboratory reports (including 2-digit years, Excel serial dates,
/// day-of-week prefixes, and mixed delimiters) into standard [DateTime] instances.
///
/// ### Simple Example:
/// ```dart
/// final dt = DateParser.parse('26/08/2023');
/// print(dt); // 2023-08-26 00:00:00.000
/// ```
///
/// ### Advanced Example:
/// ```dart
/// // Parsing complex date strings with timestamp suffixes and 2-digit century wrapping
/// final dt = DateParser.parse('Mon, 12-May-24 10:30 AM');
/// print(dt?.year); // 2024
/// ```
library date_utils;

import 'package:intl/intl.dart';

/// Robust multi-format date string parser for medical documents.
class DateParser {
  /// Parses various date string formats into a validated [DateTime].
  ///
  /// * Aggressively strips timestamps and day-of-week strings.
  /// * Handles Excel serial numbers (e.g. 43547 -> 2019-03-23).
  /// * Resolves 2-digit years relative to the current century with a 20-year future window.
  ///
  /// * [text]: The raw date string.
  /// * Returns: A [DateTime] instance, or `null` if parsing fails.
  static DateTime? parse(String text) {
    final dt = _parseRaw(text);
    if (dt == null) return null;

    // Normalizing 2-digit century rollover (e.g. year 24 -> 2024, year 95 -> 1995)
    if (dt.year < 1000) {
      final twoDigit = dt.year % 100;
      final currentYear = DateTime.now().year;
      final currentCentury = (currentYear ~/ 100) * 100;
      final cutoff = (currentYear + 20) % 100; // Allow 20 years into the future
      final y = twoDigit + ((twoDigit <= cutoff) ? currentCentury : currentCentury - 100);
      return DateTime(y, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
    }
    return dt;
  }

  static DateTime? _parseRaw(String text) {
    if (text.trim().isEmpty) return null;

    String clean = text.trim();
    // Normalize consecutive whitespace
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove day of week prefixes like "Mon, " or "Monday, "
    clean = clean.replaceAll(RegExp(r'^[a-zA-Z]+,\s*'), '');

    // Try standard ISO 8601 (e.g., 2023-01-01T12:00:00)
    try { 
      return DateTime.parse(clean); 
    } catch (_) {}

    // Strip time portion if it exists (e.g., "26/08/2018 07:01:00", "12/08/2023 10:00 AM")
    if (clean.contains(' ')) {
      final parts = clean.split(' ');
      // Remove AM/PM suffix if present
      if (['AM', 'PM'].contains(parts.last.toUpperCase())) {
        parts.removeLast();
      }
      // If the new last part matches time patterns (HH:MM or HH:MM:SS), remove it
      if (parts.isNotEmpty && RegExp(r'\d{1,2}:\d{2}(:\d{2})?').hasMatch(parts.last)) {
        parts.removeLast();
      }
      clean = parts.join(' ');
    }

    // Strip time separated by 'T'
    if (clean.contains('T')) {
      clean = clean.split('T')[0];
    }

    // Handle Excel date serial integers (e.g., 43547 is 23-Mar-2019)
    final intValue = int.tryParse(clean);
    if (intValue != null && intValue > 30000 && intValue < 60000) {
      final excelStart = DateTime(1900, 1, 1);
      // Subtract 2 days because legacy Excel incorrectly treats 1900 as a leap year
      return excelStart.add(Duration(days: intValue - 2));
    }

    // Try parsing against standardized date formats
    final formats = [
      'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy/MM/dd',
      'dd-MM-yyyy', 'MM-dd-yyyy', 'yyyy-MM-dd',
      'dd.MM.yyyy', 'MM.dd.yyyy', 'yyyy.MM.dd',
      'dd MMM yyyy', 'MMM dd yyyy', 'MMM dd, yyyy',
      'dd MMMM yyyy', 'MMMM dd yyyy', 'MMMM dd, yyyy',
      'dd / MM / yyyy',
      'dd-MMM-yyyy', 'MMM-dd-yyyy', 'yyyy-MMM-dd',
      'dd.MMM.yyyy', 'MMM.dd.yyyy', 'yyyy.MMM.dd',
      'dd-MMMM-yyyy', 'MMMM-dd-yyyy', 'yyyy-MMMM-dd',
      'dd.MMMM.yyyy', 'MMMM.dd.yyyy', 'yyyy.MMMM.dd'
    ];

    for (var fmt in formats) {
      try {
        final d = DateFormat(fmt).parseStrict(clean);
        return d;
      } catch (_) {}
    }

    // Fallback: Manual delimiter part parsing
    final sepMatch = RegExp(r'[/.-]').firstMatch(clean);
    if (sepMatch != null) {
      final parts = clean.split(sepMatch.group(0)!);
      if (parts.length == 3) {
        int? p0 = int.tryParse(parts[0].trim());
        int? p1 = int.tryParse(parts[1].trim());
        int? p2 = int.tryParse(parts[2].trim());
        
        if (p0 != null && p1 != null && p2 != null) {
          int y, m, d;
          if (p0 > 1000) { 
            y = p0; m = p1; d = p2; 
          } else if (p2 > 1000) { 
            d = p0; m = p1; y = p2; 
          } else {
            // Assume DD MM YY format if year is 2 digits
            d = p0; m = p1; y = p2; 
            if (y < 100) {
              final currentYear = DateTime.now().year;
              final currentCentury = (currentYear ~/ 100) * 100;
              final cutoff = currentYear % 100;
              y += (y <= cutoff) ? currentCentury : currentCentury - 100;
            }
          }
          try {
            final dt = DateTime(y, m, d);
            // Verify date didn't roll over (e.g. Feb 30 -> Mar 2)
            if (dt.year == y && dt.month == m && dt.day == d) {
              return dt;
            }
          } catch (_) {}
        }
      }
    }

    return null;
  }
}
