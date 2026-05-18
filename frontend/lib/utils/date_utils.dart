import 'package:intl/intl.dart';

class DateParser {
  /// Parses various date string formats into a DateTime.
  /// Aggressively strips time portions and handles 2-digit years.
  static DateTime? parse(String text) {
    if (text.trim().isEmpty) return null;

    String clean = text.trim();
    // Normalize multiple spaces
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
      // Remove AM/PM if present
      if (['AM', 'PM'].contains(parts.last.toUpperCase())) {
        parts.removeLast();
      }
      // If the new last part looks like a time (HH:MM or HH:MM:SS), remove it
      if (parts.isNotEmpty && RegExp(r'\d{1,2}:\d{2}(:\d{2})?').hasMatch(parts.last)) {
        parts.removeLast();
      }
      clean = parts.join(' ');
    }

    // Strip time separated by 'T'
    if (clean.contains('T')) {
      clean = clean.split('T')[0];
    }

    // Try parsing with common formats
    final formats = [
      'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy/MM/dd',
      'dd-MM-yyyy', 'MM-dd-yyyy', 'yyyy-MM-dd',
      'dd.MM.yyyy', 'MM.dd.yyyy', 'yyyy.MM.dd',
      'dd MMM yyyy', 'MMM dd yyyy', 'MMM dd, yyyy',
      'dd MMMM yyyy', 'MMMM dd yyyy', 'MMMM dd, yyyy',
      'dd / MM / yyyy'
    ];

    for (var fmt in formats) {
      try {
        final d = DateFormat(fmt).parseStrict(clean);
        return d;
      } catch (_) {}
    }

    // Fallback: Manual generic part parsing (supports 2-digit years)
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
            // Verify it didn't rollover (e.g. Feb 30 -> Mar 2)
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
