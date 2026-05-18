import re

with open('frontend/lib/utils/unit_converter.dart', 'r') as f:
    content = f.read()

# We need to replace the conversion rules block to be bidirectional.
# We can just write a quick script to generate the bidirectional Dart code.

new_rules = """
    // --- Conversion Rules (Bidirectional) ---

    // Helper for bidirectional conversion
    bool tryConvert(List<String> units1, List<String> units2, double factor) {
      if (units1.contains(extUnit) && units2.contains(stdUnit)) {
        convertedNumber = number * factor;
        return true;
      } else if (units2.contains(extUnit) && units1.contains(stdUnit)) {
        convertedNumber = number / factor;
        return true;
      }
      return false;
    }

    // 1. Cholesterol
    if (['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl'].contains(key)) {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 38.67);
    }
    // 2. Triglycerides
    else if (key == 'triglycerides_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 88.57);
    }
    // 3. Glucose
    else if (['fasting_glucose_mg_dl', 'random_glucose_mg_dl', 'pp_glucose_mg_dl', 'fbs_mg_dl', 'plbs_mg_dl'].contains(key)) {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 18.018);
    }
    // 4. Creatinine
    else if (key == 'creatinine_mg_dl') {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 88.42);
    }
    // 5. Bilirubin
    else if (['bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl'].contains(key)) {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 17.1);
    }
    // 6. Uric Acid
    else if (key == 'uric_acid_mg_dl') {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 59.48);
    }
    // 7. Urea
    else if (key == 'urea_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 6.006);
    }
    // 8. Calcium
    else if (key == 'calcium_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 4.0);
    }
    // 9. Phosphorus
    else if (key == 'phosphorus_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 3.097);
    }
    // 10. Iron / UIBC / TIBC
    else if (['iron_ug_dl', 'uibc_ug_dl', 'tibc_ug_dl'].contains(key)) {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['ug/dl'], 5.59);
    }
    // 11. Proteins
    else if (['protein_total_g_dl', 'albumin_g_dl', 'globulin_g_dl'].contains(key)) {
      didConvert = tryConvert(['g/l'], ['g/dl'], 1 / 10.0);
    }
    // 12. T3 Total
    else if (key == 'tt3_ng_dl') {
      didConvert = tryConvert(['nmol/l'], ['ng/dl'], 1 / 0.01536);
    }
    // 13. T4 Total
    else if (key == 'tt4_ug_dl') {
      didConvert = tryConvert(['nmol/l'], ['ug/dl'], 1 / 12.87);
    }
"""

# Replace between "// --- Conversion Rules ---" and "if (didConvert) {"
start = content.find("// --- Conversion Rules ---")
end = content.find("if (didConvert) {")
if start != -1 and end != -1:
    content = content[:start] + new_rules + "    " + content[end:]

# Let's also add convertRange function to UnitConverter
convert_range_func = """
  /// Converts a reference range string from one unit to another
  static String convertRange(String key, String range, String fromUnit, String toUnit) {
    if (range.isEmpty || fromUnit == toUnit) return range;
    
    // Split the range string on ' - ' or '< ' etc.
    // E.g., '8.5 - 10.5', '< 140', '> 60'
    final parts = range.split(' - ');
    if (parts.length == 2) {
      final p1 = convert(key, parts[0], fromUnit, toUnit);
      final p2 = convert(key, parts[1], fromUnit, toUnit);
      if (p1.wasConverted && p2.wasConverted) {
        return '${p1.convertedValue} - ${p2.convertedValue}';
      }
    } else {
      final p = convert(key, range, fromUnit, toUnit);
      if (p.wasConverted) return p.convertedValue;
    }
    
    return range;
  }
"""

# Insert convertRange before the last }
content = content.rstrip()
content = content[:-1] + convert_range_func + "}\n"

with open('frontend/lib/utils/unit_converter.dart', 'w') as f:
    f.write(content)
