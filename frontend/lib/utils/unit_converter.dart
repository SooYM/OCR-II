class ConversionResult {
  final String originalValue;
  final String convertedValue;
  final bool wasConverted;

  ConversionResult(this.originalValue, this.convertedValue, this.wasConverted);
}

class UnitConverter {
  /// Defines conversion logic for known keys.
  /// Converts the value FROM the extracted unit TO the standard unit defined in the dictionary.
  static ConversionResult convert(String key, String rawValue, String? extractedUnit, String standardUnit) {
    if (extractedUnit == null || extractedUnit.isEmpty) {
      return ConversionResult(rawValue, rawValue, false);
    }

    final extUnit = _normalizeUnit(extractedUnit);
    final stdUnit = _normalizeUnit(standardUnit);

    if (extUnit == stdUnit) {
      return ConversionResult(rawValue, rawValue, false);
    }

    // Try to extract the numeric portion and prefix/suffix
    // e.g. "< 3.8" -> prefix="< ", number=3.8, suffix=""
    final regex = RegExp(r'^([^\d\.]*)([0-9]*\.?[0-9]+)([^\d\.]*)$');
    final match = regex.firstMatch(rawValue.trim());

    if (match == null) {
      return ConversionResult(rawValue, rawValue, false); // Not a parsable number
    }

    final prefix = match.group(1) ?? '';
    final numStr = match.group(2) ?? '';
    final suffix = match.group(3) ?? '';

    final number = double.tryParse(numStr);
    if (number == null) return ConversionResult(rawValue, rawValue, false);

    double convertedNumber = number;
    bool didConvert = false;

    // --- Conversion Rules ---

    // 1. Cholesterol (Total, HDL, LDL, VLDL) -> mmol/L to mg/dL
    if (['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl'].contains(key)) {
      if (extUnit == 'mmol/l' && stdUnit == 'mg/dl') {
        convertedNumber = number * 38.67;
        didConvert = true;
      }
    }
    
    // 2. Triglycerides -> mmol/L to mg/dL
    else if (key == 'triglycerides_mg_dl') {
      if (extUnit == 'mmol/l' && stdUnit == 'mg/dl') {
        convertedNumber = number * 88.57;
        didConvert = true;
      }
    }

    // 3. Glucose -> mmol/L to mg/dL
    else if (['fasting_glucose_mg_dl', 'random_glucose_mg_dl', 'pp_glucose_mg_dl'].contains(key)) {
      if (extUnit == 'mmol/l' && stdUnit == 'mg/dl') {
        convertedNumber = number * 18.018;
        didConvert = true;
      }
    }

    // 4. Creatinine -> umol/L to mg/dL
    else if (key == 'creatinine_mg_dl') {
      if ((extUnit == 'umol/l' || extUnit == 'µmol/l') && stdUnit == 'mg/dl') {
        convertedNumber = number / 88.42;
        didConvert = true;
      }
    }

    // 5. Bilirubin (Total, Direct, Indirect) -> umol/L to mg/dL
    else if (['bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl'].contains(key)) {
      if ((extUnit == 'umol/l' || extUnit == 'µmol/l') && stdUnit == 'mg/dl') {
        convertedNumber = number / 17.1;
        didConvert = true;
      }
    }

    // 6. Uric Acid -> umol/L to mg/dL
    else if (key == 'uric_acid_mg_dl') {
      if ((extUnit == 'umol/l' || extUnit == 'µmol/l') && stdUnit == 'mg/dl') {
        convertedNumber = number / 59.48;
        didConvert = true;
      }
    }

    // 7. Urea -> mmol/L to mg/dL
    else if (key == 'urea_mg_dl') {
      if (extUnit == 'mmol/l' && stdUnit == 'mg/dl') {
        convertedNumber = number * 6.006;
        didConvert = true;
      }
    }

    if (didConvert) {
      // Determine formatting (1 decimal place is usually safe for mg/dL, 2 for others, but let's keep it clean)
      String formattedNumber = convertedNumber.toStringAsFixed(1);
      // Remove trailing .0
      if (formattedNumber.endsWith('.0')) {
        formattedNumber = formattedNumber.substring(0, formattedNumber.length - 2);
      }
      return ConversionResult(rawValue, '$prefix$formattedNumber$suffix', true);
    }

    return ConversionResult(rawValue, rawValue, false);
  }

  static String _normalizeUnit(String unit) {
    return unit.toLowerCase().replaceAll(' ', '');
  }
}
