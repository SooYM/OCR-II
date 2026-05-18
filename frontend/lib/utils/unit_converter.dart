class ConversionResult {
  final String originalValue;
  final String convertedValue;
  final bool wasConverted;

  ConversionResult(this.originalValue, this.convertedValue, this.wasConverted);
}

class UnitConverter {
  /// Bidirectional unit conversion for biomarker values.
  static ConversionResult convert(String key, String rawValue, String? extractedUnit, String standardUnit) {
    if (extractedUnit == null || extractedUnit.isEmpty) {
      return ConversionResult(rawValue, rawValue, false);
    }

    final extUnit = _normalizeUnit(extractedUnit);
    final stdUnit = _normalizeUnit(standardUnit);

    if (extUnit == stdUnit) {
      return ConversionResult(rawValue, rawValue, false);
    }

    // Extract numeric portion with optional prefix/suffix (e.g. "< 3.8" -> prefix="< ", number=3.8)
    final regex = RegExp(r'^([^\d\.]*)([0-9]*\.?[0-9]+)([^\d\.]*)$');
    final match = regex.firstMatch(rawValue.trim());

    if (match == null) {
      return ConversionResult(rawValue, rawValue, false);
    }

    final prefix = match.group(1) ?? '';
    final numStr = match.group(2) ?? '';
    final suffix = match.group(3) ?? '';

    final number = double.tryParse(numStr);
    if (number == null) return ConversionResult(rawValue, rawValue, false);

    double convertedNumber = number;
    bool didConvert = false;

    // --- Helper: bidirectional linear conversion ---
    // units1 -> units2: multiply by factor
    // units2 -> units1: divide by factor
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

    // ─── LIPID PROFILE ───────────────────────────────────
    // Cholesterol: 1 mmol/L = 38.67 mg/dL
    if (['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl', 'non_hdl_mg_dl'].contains(key)) {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 38.67);
    }
    // Triglycerides: 1 mmol/L = 88.57 mg/dL
    else if (key == 'triglycerides_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 88.57);
    }

    // ─── GLUCOSE ─────────────────────────────────────────
    // Glucose: 1 mmol/L = 18.018 mg/dL
    else if (['fasting_glucose_mg_dl', 'random_glucose_mg_dl', 'postprandial_glucose_mg_dl', 'fbs_mg_dl', 'plbs_mg_dl', 'estimated_avg_glucose_mg_dl'].contains(key)) {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 18.018);
    }

    // ─── KIDNEY FUNCTION ─────────────────────────────────
    // Creatinine: 1 mg/dL = 88.42 µmol/L
    else if (key == 'creatinine_mg_dl') {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 88.42);
    }
    // Urea: 1 mg/dL = 1/6.006 mmol/L
    else if (key == 'urea_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 6.006);
    }
    // BUN: 1 mg/dL = 0.357 mmol/L
    else if (key == 'bun_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 2.8);
    }
    // Uric Acid: 1 mg/dL = 59.48 µmol/L
    else if (key == 'uric_acid_mg_dl') {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 59.48);
    }
    // Sodium/Potassium/Chloride: mmol/L = mEq/L (1:1 for monovalent ions)
    else if (['sodium_mmol_l', 'potassium_mmol_l', 'chloride_mmol_l'].contains(key)) {
      didConvert = tryConvert(['mmol/l'], ['meq/l'], 1.0);
    }
    // eGFR: 1 mL/min/1.73m² = 1/60 mL/s/1.73m²
    else if (key == 'egfr_ml_min_173m2') {
      didConvert = tryConvert(['ml/s/1.73m²', 'ml/s/1.73m2'], ['ml/min/1.73m²', 'ml/min/1.73m2'], 60.0);
    }
    // Urine Creatinine: 1 mg/dL = 0.08842 mmol/L
    else if (key == 'urine_creatinine_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 11.312);
    }

    // ─── LIVER FUNCTION ──────────────────────────────────
    // Bilirubin: 1 mg/dL = 17.1 µmol/L
    else if (['bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl'].contains(key)) {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 17.1);
    }
    // Enzymes ALP/ALT/AST/GGT: 1 U/L = 0.0167 µkat/L (1/60)
    else if (['alp_u_l', 'alt_sgpt_u_l', 'ast_sgot_u_l', 'ggt_u_l'].contains(key)) {
      didConvert = tryConvert(['µkat/l', 'ukat/l'], ['u/l'], 60.0);
    }
    // Proteins (Total Protein, Albumin, Globulin): 1 g/dL = 10 g/L
    else if (['protein_total_g_dl', 'albumin_g_dl', 'globulin_g_dl'].contains(key)) {
      didConvert = tryConvert(['g/l'], ['g/dl'], 1 / 10.0);
    }

    // ─── CBC ─────────────────────────────────────────────
    // Hemoglobin / MCHC: 1 g/dL = 10 g/L
    else if (['hemoglobin_g_dl', 'mchc_g_dl'].contains(key)) {
      didConvert = tryConvert(['g/l'], ['g/dl'], 1 / 10.0);
    }
    // RBC Count: 1 mil/µL = 1 × 10^12/L (1:1)
    else if (key == 'rbc_count_mil_ul') {
      didConvert = tryConvert(['mil/ul', 'mil/µl'], ['10^12/l'], 1.0);
    }
    // WBC: 1000 cells/µL = 1 × 10^9/L
    else if (key == 'wbc_cells_ul') {
      didConvert = tryConvert(['10^9/l'], ['cells/ul', 'cells/µl'], 1000.0);
    }
    // Absolute counts (Neutrophils, Lymphocytes, Monocytes, Eosinophils, Basophils): cells/µL → 10^9/L
    else if (['abs_neutrophils', 'abs_lymphocytes', 'abs_monocytes', 'abs_eosinophils', 'abs_basophils'].contains(key)) {
      didConvert = tryConvert(['10^9/l'], ['cells/ul', 'cells/µl'], 1000.0);
    }
    // Platelet Count: 1 ×10³/µL = 1 × 10^9/L (1:1)
    else if (key == 'platelet_count_x10_3_ul') {
      didConvert = tryConvert(['x10³/ul', 'x10^3/ul'], ['10^9/l'], 1.0);
    }

    // ─── IRON PROFILE ────────────────────────────────────
    // Iron/UIBC/TIBC: 1 µg/dL = 0.179 µmol/L (factor = 5.587)
    else if (['iron_ug_dl', 'uibc_ug_dl', 'tibc_ug_dl'].contains(key)) {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['ug/dl', 'µg/dl'], 5.59);
    }

    // ─── CALCIUM & PHOSPHORUS ────────────────────────────
    else if (key == 'calcium_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 4.0);
    }
    else if (key == 'phosphorus_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 3.097);
    }

    // ─── THYROID PROFILE ─────────────────────────────────
    // T3: 1 ng/dL = 0.01536 nmol/L
    else if (key == 'tt3_ng_dl') {
      didConvert = tryConvert(['nmol/l'], ['ng/dl'], 1 / 0.01536);
    }
    // T4: 1 µg/dL = 12.87 nmol/L
    else if (key == 'tt4_ug_dl') {
      didConvert = tryConvert(['nmol/l'], ['ug/dl', 'µg/dl'], 1 / 12.87);
    }
    // TSH: µIU/mL = mIU/L (1:1, same unit different notation)
    else if (key == 'tsh_uiu_ml') {
      didConvert = tryConvert(['uiu/ml', 'µiu/ml'], ['miu/l'], 1.0);
    }

    // ─── HbA1c (Non-linear conversion) ───────────────────
    // NGSP (%) ↔ IFCC (mmol/mol): mmol/mol = (% - 2.152) / 0.09148
    else if (key == 'hba1c_pct') {
      if (['%'].contains(extUnit) && ['mmol/mol'].contains(stdUnit)) {
        convertedNumber = (number - 2.152) / 0.09148;
        didConvert = true;
      } else if (['mmol/mol'].contains(extUnit) && ['%'].contains(stdUnit)) {
        convertedNumber = (number * 0.09148) + 2.152;
        didConvert = true;
      }
    }

    if (didConvert) {
      return ConversionResult(rawValue, '$prefix${_formatNumber(convertedNumber)}$suffix', true);
    }

    return ConversionResult(rawValue, rawValue, false);
  }

  static String _normalizeUnit(String unit) {
    return unit.toLowerCase().replaceAll(' ', '');
  }

  /// Smart number formatting based on magnitude
  static String _formatNumber(double n) {
    String result;
    if (n.abs() >= 100) {
      result = n.toStringAsFixed(0);
    } else if (n.abs() >= 10) {
      result = n.toStringAsFixed(1);
    } else if (n.abs() >= 1) {
      result = n.toStringAsFixed(2);
    } else {
      result = n.toStringAsFixed(3);
    }
    // Remove trailing zeros after decimal point
    if (result.contains('.')) {
      result = result.replaceAll(RegExp(r'0+$'), '');
      result = result.replaceAll(RegExp(r'\.$'), '');
    }
    return result;
  }

  /// Converts a reference range string from one unit to another
  static String convertRange(String key, String range, String fromUnit, String toUnit) {
    if (range.isEmpty || fromUnit == toUnit) return range;
    
    // Split the range string on hyphen with optional spaces
    final regex = RegExp(r'\s*-\s*');
    final parts = range.split(regex);
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
}
