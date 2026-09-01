/// Bidirectional Clinical Unit Conversion Engine.
///
/// This module normalizes diverse medical laboratory measurement units
/// (SI vs Conventional) to standard units across 92+ parameters.
///
/// ### Simple Example:
/// ```dart
/// // Converting total cholesterol from mmol/L to standard mg/dL
/// final result = UnitConverter.convert('total_cholesterol_mg_dl', '5.17', 'mmol/L', 'mg/dL');
/// print(result.convertedValue); // '200'
/// ```
///
/// ### Advanced Example:
/// ```dart
/// // Converting non-linear HbA1c reference range between % and mmol/mol
/// final convertedRange = UnitConverter.convertRange('hba1c_pct', '4.0 - 5.6', '%', 'mmol/mol');
/// print(convertedRange); // '20 - 38'
/// ```
library unit_converter;

import 'biomarker_dictionary.dart';

/// Container encapsulating the outcome of a biomarker unit transformation.
class ConversionResult {
  /// The input value prior to conversion.
  final String originalValue;

  /// The resulting value after applying conversion factors.
  final String convertedValue;

  /// Whether a mathematical transformation was executed.
  final bool wasConverted;

  /// Constructs a [ConversionResult].
  ConversionResult(this.originalValue, this.convertedValue, this.wasConverted);
}

/// Core clinical unit converter utility class providing bidirectional linear
/// and polynomial transformations.
class UnitConverter {
  /// Converts a numeric biomarker measurement from [extractedUnit] to [standardUnit].
  ///
  /// * [key]: Biomarker database column key (e.g. `'total_cholesterol_mg_dl'`).
  /// * [rawValue]: Raw string containing numeric value, optionally with symbols (e.g. `"< 3.8"`).
  /// * [extractedUnit]: Unit extracted from the lab report (e.g. `'mmol/L'`).
  /// * [standardUnit]: Target database standard unit (e.g. `'mg/dL'`).
  /// * Returns: A [ConversionResult] with converted or original value.
  static ConversionResult convert(String key, String rawValue, String? extractedUnit, String standardUnit) {
    if (extractedUnit == null || extractedUnit.isEmpty) {
      return ConversionResult(rawValue, rawValue, false);
    }

    final extUnit = _normalizeUnit(extractedUnit);
    final stdUnit = _normalizeUnit(standardUnit);

    // No conversion needed if units match
    if (extUnit == stdUnit) {
      return ConversionResult(rawValue, rawValue, false);
    }

    // Extract numeric portion with optional leading/trailing symbols (e.g. "< 3.8" -> prefix="< ", number=3.8)
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

    // Helper: bidirectional linear transformation
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
    // Cholesterol: 1 mmol/L = 38.67 mg/dL (molecular weight approx 386.65 g/mol)
    if (['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl', 'non_hdl_mg_dl'].contains(key)) {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 38.67);
    }
    // Triglycerides: 1 mmol/L = 88.57 mg/dL (molecular weight approx 885.7 g/mol)
    else if (key == 'triglycerides_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 88.57);
    }

    // ─── GLUCOSE ─────────────────────────────────────────
    // Glucose: 1 mmol/L = 18.018 mg/dL (molecular weight approx 180.16 g/mol)
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
    // Blood Urea Nitrogen (BUN): 1 mg/dL = 0.357 mmol/L (Factor = 2.80)
    else if (key == 'bun_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 2.8);
    }
    // Uric Acid: 1 mg/dL = 59.48 µmol/L
    else if (key == 'uric_acid_mg_dl') {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 59.48);
    }
    // Monovalent Electrolytes (Na+, K+, Cl-): mmol/L = mEq/L (1:1 equivalent)
    else if (['sodium_mmol_l', 'potassium_mmol_l', 'chloride_mmol_l'].contains(key)) {
      didConvert = tryConvert(['mmol/l'], ['meq/l'], 1.0);
    }
    // eGFR: 1 mL/min/1.73m² = 1/60 mL/s/1.73m²
    else if (key == 'egfr_ml_min_173m2') {
      didConvert = tryConvert(['ml/s/1.73m²', 'ml/s/1.73m2'], ['ml/min/1.73m²', 'ml/min/1.73m2'], 60.0);
    }
    // Urine Creatinine: 1 mg/dL = 0.08842 mmol/L (factor = 11.312)
    else if (key == 'urine_creatinine_mg_dl') {
      didConvert = tryConvert(['mmol/l'], ['mg/dl'], 11.312);
    }

    // ─── LIVER FUNCTION ──────────────────────────────────
    // Bilirubin: 1 mg/dL = 17.1 µmol/L
    else if (['bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl'].contains(key)) {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['mg/dl'], 1 / 17.1);
    }
    // Enzymes (ALP, ALT, AST, GGT): 1 U/L = 0.0167 µkat/L (60 U/L = 1 µkat/L)
    else if (['alp_u_l', 'alt_sgpt_u_l', 'ast_sgot_u_l', 'ggt_u_l'].contains(key)) {
      didConvert = tryConvert(['µkat/l', 'ukat/l'], ['u/l'], 60.0);
    }
    // Total Proteins / Albumin: 1 g/dL = 10 g/L
    else if (['protein_total_g_dl', 'albumin_g_dl', 'globulin_g_dl'].contains(key)) {
      didConvert = tryConvert(['g/l'], ['g/dl'], 1 / 10.0);
    }

    // ─── CBC ─────────────────────────────────────────────
    // Hemoglobin / MCHC: 1 g/dL = 10 g/L
    else if (['hemoglobin_g_dl', 'mchc_g_dl'].contains(key)) {
      didConvert = tryConvert(['g/l'], ['g/dl'], 1 / 10.0);
    }
    // RBC Count: 1 mil/µL = 1 × 10^12/L (1:1 equivalence)
    else if (key == 'rbc_count_mil_ul') {
      didConvert = tryConvert(['mil/ul', 'mil/µl'], ['10^12/l'], 1.0);
    }
    // WBC & Absolute differential counts: 10^9/L = 1,000 cells/µL
    else if (['wbc_cells_ul', 'abs_neutrophils', 'abs_lymphocytes', 'abs_monocytes', 'abs_eosinophils', 'abs_basophils'].contains(key)) {
      didConvert = tryConvert(['10^9/l'], ['cells/ul', 'cells/µl'], 1000.0);
    }
    // Platelet Count: 1 × 10³/µL = 1 × 10^9/L (1:1 equivalence)
    else if (key == 'platelet_count_x10_3_ul') {
      didConvert = tryConvert(['x10³/ul', 'x10^3/ul'], ['10^9/l'], 1.0);
    }

    // ─── IRON PROFILE ────────────────────────────────────
    // Iron / UIBC / TIBC: 1 µg/dL = 0.179 µmol/L (Factor = 5.587)
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
    // TSH: µIU/mL = mIU/L (1:1 notation equivalent)
    else if (key == 'tsh_uiu_ml') {
      didConvert = tryConvert(['uiu/ml', 'µiu/ml'], ['miu/l'], 1.0);
    }

    // ─── SPECIALIZED CLINICAL RATIOS ─────────────────────
    else if (key == 'proteins') {
      didConvert = tryConvert(['g/l'], ['mg/dl'], 0.01);
    }
    else if (key == 'urobilinogen') {
      didConvert = tryConvert(['umol/l', 'µmol/l'], ['eu/dl'], 17.0);
    }
    else if (['wbc_pus_cells_hpf', 'rbc', 'epithelial_cells_hpf'].contains(key)) {
      didConvert = tryConvert(['x10^6/l', 'cells/ul', 'cells/µl', '10^6/l'], ['/hpf'], 1.0);
    }
    else if (key == 'albumin_creatinine_ratio') {
      didConvert = tryConvert(['mg/mmol'], ['mg/g'], 0.113);
    }
    else if (['hematocrit_pct', 'rdw_cv_pct', 'platelet_rdw_pct', 'p_lcr_pct', 'img_pct', 'imm_pct', 'iml_pct', 'lic_pct', 'transferrin_saturation_pct', 'hbf_pct'].contains(key)) {
      didConvert = tryConvert(['fraction', 'l/l'], ['%'], 0.01);
    }
    else if (key == 'pct_pct') {
      didConvert = tryConvert(['ml/l'], ['%'], 10.0);
    }

    // ─── HbA1c (Non-linear IFCC ↔ NGSP Master Equation) ──
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

  /// Normalizes unit strings by removing whitespace and lowercasing.
  static String _normalizeUnit(String unit) {
    return unit.toLowerCase().replaceAll(' ', '');
  }

  /// Formats numeric values with adaptive precision based on magnitude.
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
    // Remove redundant trailing zeroes after decimal point
    if (result.contains('.')) {
      result = result.replaceAll(RegExp(r'0+$'), '');
      result = result.replaceAll(RegExp(r'\.$'), '');
    }
    return result;
  }

  /// Converts a biological reference range string between units.
  ///
  /// * [key]: Biomarker parameter identifier.
  /// * [range]: Raw reference range string (e.g. `'4.0 - 6.0'`).
  /// * [fromUnit]: Original unit.
  /// * [toUnit]: Target unit.
  /// * Returns: The converted reference range string.
  static String convertRange(String key, String range, String fromUnit, String toUnit) {
    if (range.isEmpty || fromUnit == toUnit) return range;

    // First attempt to look up hand-curated reference ranges from the dictionary
    try {
      final entry = BiomarkerDictionary.getEntryByKey(key);
      if (entry != null) {
        final normTo = _normalizeUnit(toUnit);
        final normStdUnit = _normalizeUnit(entry.unit);

        // If toUnit is conventional, return conventional
        if (normTo == normStdUnit) {
          if (entry.referenceRange != null && entry.referenceRange!.isNotEmpty) {
            return entry.referenceRange!;
          }
        } else {
          // If toUnit is SI, return SI
          if (entry.referenceRangeSI != null && entry.referenceRangeSI!.isNotEmpty && entry.referenceRangeSI != 'N/A') {
            return entry.referenceRangeSI!;
          }
        }
      }
    } catch (_) {}

    // Fallback to regex-based numeric scale conversion
    final regex = RegExp(r'(\d*\.?\d+)');
    
    return range.replaceAllMapped(regex, (match) {
      final numStr = match.group(0)!;
      final res = convert(key, numStr, fromUnit, toUnit);
      return res.wasConverted ? res.convertedValue : numStr;
    });
  }
}
