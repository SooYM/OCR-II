/// Standard biomarker data dictionary with fuzzy matching.
class BiomarkerEntry {
  final String key;
  final String standardName;
  final String unit;
  final String? referenceRange;
  final List<String> aliases;

  const BiomarkerEntry({
    required this.key,
    required this.standardName,
    required this.unit,
    this.referenceRange,
    this.aliases = const [],
  });
}

class BiomarkerDictionary {
  static const List<BiomarkerEntry> entries = [
    // ─── CBC ──────────────────────────────────────────────
    BiomarkerEntry(key: 'hemoglobin_g_dl', standardName: 'Hemoglobin', unit: 'g/dL', referenceRange: '12.0 - 17.5', aliases: ['Hb', 'Haemoglobin', 'HGB', 'Hgb']),
    BiomarkerEntry(key: 'rbc_count_mil_ul', standardName: 'RBC Count', unit: 'mil/uL', referenceRange: '4.5 - 5.5', aliases: ['Red Blood Cell Count', 'RBC', 'Erythrocyte Count']),
    BiomarkerEntry(key: 'hematocrit_pct', standardName: 'Hematocrit', unit: '%', referenceRange: '36 - 50', aliases: ['HCT', 'Haematocrit', 'PCV', 'Packed Cell Volume']),
    BiomarkerEntry(key: 'mcv_fl', standardName: 'MCV', unit: 'fL', referenceRange: '80 - 100', aliases: ['Mean Corpuscular Volume']),
    BiomarkerEntry(key: 'mch_pg', standardName: 'MCH', unit: 'pg', referenceRange: '27 - 33', aliases: ['Mean Corpuscular Hemoglobin', 'Mean Corpuscular Haemoglobin']),
    BiomarkerEntry(key: 'mchc_g_dl', standardName: 'MCHC', unit: 'g/dL', referenceRange: '32 - 36', aliases: ['Mean Corpuscular Hemoglobin Concentration']),
    BiomarkerEntry(key: 'rdw_cv_pct', standardName: 'RDW-CV', unit: '%', referenceRange: '11.5 - 14.5', aliases: ['RDW', 'Red Cell Distribution Width']),
    BiomarkerEntry(key: 'rdw_sd_fl', standardName: 'RDW-SD', unit: 'fL', referenceRange: '35 - 56', aliases: []),
    BiomarkerEntry(key: 'wbc_cells_ul', standardName: 'WBC', unit: 'cells/uL', referenceRange: '4000 - 11000', aliases: ['White Blood Cell Count', 'TLC', 'Total Leucocyte Count', 'Total Leukocyte Count', 'Leucocyte Count']),
    BiomarkerEntry(key: 'neutrophils_pct', standardName: 'Neutrophils', unit: '%', referenceRange: '40 - 70', aliases: ['Neutrophil', 'Neut', 'Segmented Neutrophils']),
    BiomarkerEntry(key: 'lymphocytes_pct', standardName: 'Lymphocytes', unit: '%', referenceRange: '20 - 40', aliases: ['Lymphocyte', 'Lymph']),
    BiomarkerEntry(key: 'eosinophils_pct', standardName: 'Eosinophils', unit: '%', referenceRange: '1 - 6', aliases: ['Eosinophil', 'Eosino', 'Eos']),
    BiomarkerEntry(key: 'monocytes_pct', standardName: 'Monocytes', unit: '%', referenceRange: '2 - 10', aliases: ['Monocyte', 'Mono']),
    BiomarkerEntry(key: 'basophils_pct', standardName: 'Basophils', unit: '%', referenceRange: '0 - 2', aliases: ['Basophil', 'Baso']),
    BiomarkerEntry(key: 'abs_neutrophils', standardName: 'Abs. Neutrophils', unit: 'cells/uL', referenceRange: '2000 - 7000', aliases: ['ANC', 'Absolute Neutrophil Count']),
    BiomarkerEntry(key: 'abs_lymphocytes', standardName: 'Abs. Lymphocytes', unit: 'cells/uL', referenceRange: '1000 - 3000', aliases: ['ALC', 'Absolute Lymphocyte Count']),
    BiomarkerEntry(key: 'abs_monocytes', standardName: 'Abs. Monocytes', unit: 'cells/uL', aliases: ['Absolute Monocyte Count']),
    BiomarkerEntry(key: 'abs_eosinophils', standardName: 'Abs. Eosinophils', unit: 'cells/uL', aliases: ['AEC', 'Absolute Eosinophil Count']),
    BiomarkerEntry(key: 'abs_basophils', standardName: 'Abs. Basophils', unit: 'cells/uL', aliases: ['Absolute Basophil Count']),

    // ─── Platelet ─────────────────────────────────────────
    BiomarkerEntry(key: 'platelet_count_x10_3_ul', standardName: 'Platelet Count', unit: 'x10³/uL', referenceRange: '150 - 400', aliases: ['PLT', 'Platelets', 'Thrombocyte Count']),
    BiomarkerEntry(key: 'mpv_fl', standardName: 'MPV', unit: 'fL', referenceRange: '7.5 - 11.5', aliases: ['Mean Platelet Volume']),
    BiomarkerEntry(key: 'platelet_rdw_pct', standardName: 'Platelet RDW', unit: '%', aliases: ['PDW', 'Platelet Distribution Width']),
    BiomarkerEntry(key: 'pct_pct', standardName: 'PCT', unit: '%', aliases: ['Plateletcrit']),
    BiomarkerEntry(key: 'p_lcr_pct', standardName: 'P-LCR', unit: '%', aliases: ['Platelet Large Cell Ratio']),
    BiomarkerEntry(key: 'img_pct', standardName: 'IMG', unit: '%', aliases: []),
    BiomarkerEntry(key: 'imm_pct', standardName: 'IMM', unit: '%', aliases: []),
    BiomarkerEntry(key: 'iml_pct', standardName: 'IML', unit: '%', aliases: []),
    BiomarkerEntry(key: 'lic_pct', standardName: 'LIC', unit: '%', aliases: []),

    // ─── Lipid Profile ────────────────────────────────────
    BiomarkerEntry(key: 'total_cholesterol_mg_dl', standardName: 'Total Cholesterol', unit: 'mg/dL', referenceRange: '< 200', aliases: ['Cholesterol', 'Tot. Cholesterol', 'TC', 'Chol', 'S. Cholesterol', 'Serum Cholesterol']),
    BiomarkerEntry(key: 'hdl_mg_dl', standardName: 'HDL Cholesterol', unit: 'mg/dL', referenceRange: '> 40', aliases: ['HDL', 'HDL-C', 'High Density Lipoprotein']),
    BiomarkerEntry(key: 'ldl_mg_dl', standardName: 'LDL Cholesterol', unit: 'mg/dL', referenceRange: '< 100', aliases: ['LDL', 'LDL-C', 'Low Density Lipoprotein']),
    BiomarkerEntry(key: 'vldl_mg_dl', standardName: 'VLDL Cholesterol', unit: 'mg/dL', referenceRange: '< 30', aliases: ['VLDL', 'VLDL-C', 'Very Low Density Lipoprotein']),
    BiomarkerEntry(key: 'triglycerides_mg_dl', standardName: 'Triglycerides', unit: 'mg/dL', referenceRange: '< 150', aliases: ['TG', 'Trigs', 'Triglyceride', 'S. Triglycerides']),
    BiomarkerEntry(key: 'non_hdl_mg_dl', standardName: 'Non-HDL Cholesterol', unit: 'mg/dL', aliases: ['Non HDL', 'Non-HDL']),
    BiomarkerEntry(key: 'total_hdl_ratio', standardName: 'Total/HDL Ratio', unit: '', aliases: ['TC/HDL', 'Cholesterol/HDL Ratio']),
    BiomarkerEntry(key: 'ldl_hdl_ratio', standardName: 'LDL/HDL Ratio', unit: '', aliases: []),
    BiomarkerEntry(key: 'hdl_ldl_ratio', standardName: 'HDL/LDL Ratio', unit: '', aliases: []),

    // ─── Liver Function ───────────────────────────────────
    BiomarkerEntry(key: 'bilirubin_total_mg_dl', standardName: 'Bilirubin Total', unit: 'mg/dL', referenceRange: '0.1 - 1.2', aliases: ['Total Bilirubin', 'T. Bilirubin', 'S. Bilirubin']),
    BiomarkerEntry(key: 'bilirubin_direct_mg_dl', standardName: 'Bilirubin Direct', unit: 'mg/dL', referenceRange: '0.0 - 0.3', aliases: ['Direct Bilirubin', 'Conjugated Bilirubin']),
    BiomarkerEntry(key: 'bilirubin_indirect_mg_dl', standardName: 'Bilirubin Indirect', unit: 'mg/dL', referenceRange: '0.1 - 1.0', aliases: ['Indirect Bilirubin', 'Unconjugated Bilirubin']),
    BiomarkerEntry(key: 'alp_u_l', standardName: 'ALP', unit: 'U/L', referenceRange: '44 - 147', aliases: ['Alkaline Phosphatase', 'Alk. Phosphatase']),
    BiomarkerEntry(key: 'alt_sgpt_u_l', standardName: 'ALT (SGPT)', unit: 'U/L', referenceRange: '7 - 56', aliases: ['ALT', 'SGPT', 'Alanine Aminotransferase', 'Alanine Transaminase']),
    BiomarkerEntry(key: 'ast_sgot_u_l', standardName: 'AST (SGOT)', unit: 'U/L', referenceRange: '10 - 40', aliases: ['AST', 'SGOT', 'Aspartate Aminotransferase', 'Aspartate Transaminase']),
    BiomarkerEntry(key: 'ggt_u_l', standardName: 'GGT', unit: 'U/L', referenceRange: '9 - 48', aliases: ['Gamma GT', 'Gamma Glutamyl Transferase', 'Gamma-Glutamyl Transpeptidase']),
    BiomarkerEntry(key: 'protein_total_g_dl', standardName: 'Total Protein', unit: 'g/dL', referenceRange: '6.0 - 8.3', aliases: ['Protein Total', 'S. Protein', 'Serum Protein', 'Total Proteins']),
    BiomarkerEntry(key: 'albumin_g_dl', standardName: 'Albumin', unit: 'g/dL', referenceRange: '3.5 - 5.5', aliases: ['S. Albumin', 'Serum Albumin', 'Alb']),
    BiomarkerEntry(key: 'globulin_g_dl', standardName: 'Globulin', unit: 'g/dL', referenceRange: '2.0 - 3.5', aliases: ['S. Globulin', 'Serum Globulin']),
    BiomarkerEntry(key: 'a_g_ratio', standardName: 'A/G Ratio', unit: '', referenceRange: '1.1 - 2.5', aliases: ['Albumin/Globulin Ratio', 'AG Ratio']),

    // ─── Kidney Function ──────────────────────────────────
    BiomarkerEntry(key: 'creatinine_mg_dl', standardName: 'Creatinine', unit: 'mg/dL', referenceRange: '0.7 - 1.3', aliases: ['S. Creatinine', 'Serum Creatinine', 'Creat']),
    BiomarkerEntry(key: 'urea_mg_dl', standardName: 'Urea', unit: 'mg/dL', referenceRange: '15 - 40', aliases: ['Blood Urea', 'S. Urea', 'Serum Urea']),
    BiomarkerEntry(key: 'bun_mg_dl', standardName: 'BUN', unit: 'mg/dL', referenceRange: '7 - 20', aliases: ['Blood Urea Nitrogen']),
    BiomarkerEntry(key: 'bun_creatinine_ratio', standardName: 'BUN/Creatinine Ratio', unit: '', aliases: []),
    BiomarkerEntry(key: 'sodium_mmol_l', standardName: 'Sodium', unit: 'mmol/L', referenceRange: '136 - 145', aliases: ['Na', 'Na+', 'S. Sodium', 'Serum Sodium']),
    BiomarkerEntry(key: 'potassium_mmol_l', standardName: 'Potassium', unit: 'mmol/L', referenceRange: '3.5 - 5.1', aliases: ['K', 'K+', 'S. Potassium', 'Serum Potassium']),
    BiomarkerEntry(key: 'chloride_mmol_l', standardName: 'Chloride', unit: 'mmol/L', referenceRange: '98 - 106', aliases: ['Cl', 'Cl-', 'S. Chloride', 'Serum Chloride']),
    BiomarkerEntry(key: 'uric_acid_mg_dl', standardName: 'Uric Acid', unit: 'mg/dL', referenceRange: '3.5 - 7.2', aliases: ['S. Uric Acid', 'Serum Uric Acid']),
    BiomarkerEntry(key: 'egfr_ml_min_173m2', standardName: 'eGFR', unit: 'mL/min/1.73m²', referenceRange: '> 90', aliases: ['Estimated GFR', 'Glomerular Filtration Rate']),

    // ─── Iron Profile ─────────────────────────────────────
    BiomarkerEntry(key: 'iron_ug_dl', standardName: 'Iron', unit: 'ug/dL', referenceRange: '60 - 170', aliases: ['S. Iron', 'Serum Iron', 'Fe']),
    BiomarkerEntry(key: 'uibc_ug_dl', standardName: 'UIBC', unit: 'ug/dL', aliases: ['Unsaturated Iron Binding Capacity']),
    BiomarkerEntry(key: 'tibc_ug_dl', standardName: 'TIBC', unit: 'ug/dL', referenceRange: '250 - 370', aliases: ['Total Iron Binding Capacity']),
    BiomarkerEntry(key: 'transferrin_saturation_pct', standardName: 'Transferrin Saturation', unit: '%', referenceRange: '20 - 50', aliases: ['TSAT', 'Iron Saturation']),

    // ─── HbA1c ────────────────────────────────────────────
    BiomarkerEntry(key: 'hba1c_pct', standardName: 'HbA1c', unit: '%', referenceRange: '< 5.7', aliases: ['Glycated Hemoglobin', 'Glycosylated Hemoglobin', 'A1C', 'Glycated Haemoglobin']),
    BiomarkerEntry(key: 'estimated_avg_glucose_mg_dl', standardName: 'Estimated Avg. Glucose', unit: 'mg/dL', aliases: ['eAG', 'Estimated Average Glucose']),
    BiomarkerEntry(key: 'hbf_pct', standardName: 'HbF', unit: '%', aliases: ['Fetal Hemoglobin']),

    // ─── Urine ACR ────────────────────────────────────────
    BiomarkerEntry(key: 'urine_albumin_mg_l', standardName: 'Urine Albumin', unit: 'mg/L', aliases: ['Microalbumin', 'U. Albumin']),
    BiomarkerEntry(key: 'urine_creatinine_mg_dl', standardName: 'Urine Creatinine', unit: 'mg/dL', aliases: ['U. Creatinine']),
    BiomarkerEntry(key: 'albumin_creatinine_ratio', standardName: 'Albumin/Creatinine Ratio', unit: '', referenceRange: '< 30', aliases: ['ACR', 'Urine ACR']),

    // ─── Calcium & Phosphorus ─────────────────────────────
    BiomarkerEntry(key: 'calcium_mg_dl', standardName: 'Calcium', unit: 'mg/dL', referenceRange: '8.5 - 10.5', aliases: ['Ca', 'Ca++', 'S. Calcium', 'Serum Calcium', 'Total Calcium']),
    BiomarkerEntry(key: 'phosphorus_mg_dl', standardName: 'Phosphorus', unit: 'mg/dL', referenceRange: '2.5 - 4.5', aliases: ['Phosphate', 'Phos', 'S. Phosphorus', 'Inorganic Phosphorus']),

    // ─── Thyroid Profile ──────────────────────────────────
    BiomarkerEntry(key: 'tt3_ng_dl', standardName: 'Total T3', unit: 'ng/dL', referenceRange: '80 - 200', aliases: ['T3', 'TT3', 'Triiodothyronine']),
    BiomarkerEntry(key: 'tt4_ug_dl', standardName: 'Total T4', unit: 'ug/dL', referenceRange: '5.1 - 14.1', aliases: ['T4', 'TT4', 'Thyroxine']),
    BiomarkerEntry(key: 'tsh_uiu_ml', standardName: 'TSH', unit: 'uIU/mL', referenceRange: '0.4 - 4.0', aliases: ['Thyroid Stimulating Hormone', 'Thyrotropin']),

    // ─── Glucose ──────────────────────────────────────────
    BiomarkerEntry(key: 'fasting_glucose_mg_dl', standardName: 'Fasting Glucose', unit: 'mg/dL', referenceRange: '70 - 100', aliases: ['FBS', 'Fasting Blood Sugar', 'Fasting Blood Glucose', 'Glucose Fasting', 'F. Glucose']),
    BiomarkerEntry(key: 'postprandial_glucose_mg_dl', standardName: 'Postprandial Glucose', unit: 'mg/dL', referenceRange: '< 140', aliases: ['PPBS', 'PP Blood Sugar', 'PP Glucose', 'Post Prandial Blood Sugar', 'Glucose PP']),
    BiomarkerEntry(key: 'fbs_mg_dl', standardName: 'FBS', unit: 'mg/dL', referenceRange: '70 - 100', aliases: ['Fasting Blood Sugar']),
    BiomarkerEntry(key: 'plbs_mg_dl', standardName: 'PLBS', unit: 'mg/dL', referenceRange: '< 140', aliases: ['Post Lunch Blood Sugar']),

    // ─── Urinalysis ───────────────────────────────────────
    BiomarkerEntry(key: 'urine_colour', standardName: 'Urine Colour', unit: '', aliases: ['Urine Color', 'Colour']),
    BiomarkerEntry(key: 'appearance', standardName: 'Appearance', unit: '', aliases: ['Urine Appearance']),
    BiomarkerEntry(key: 'specific_gravity', standardName: 'Specific Gravity', unit: '', referenceRange: '1.005 - 1.030', aliases: ['Sp. Gravity', 'SG']),
    BiomarkerEntry(key: 'ph', standardName: 'pH', unit: '', referenceRange: '4.5 - 8.0', aliases: ['Urine pH']),
    BiomarkerEntry(key: 'proteins', standardName: 'Proteins', unit: '', aliases: ['Urine Protein', 'Protein']),
    BiomarkerEntry(key: 'glucose', standardName: 'Glucose (Urine)', unit: '', aliases: ['Urine Glucose', 'Sugar']),
    BiomarkerEntry(key: 'bilirubin', standardName: 'Bilirubin (Urine)', unit: '', aliases: ['Urine Bilirubin']),
    BiomarkerEntry(key: 'ketones', standardName: 'Ketones', unit: '', aliases: ['Urine Ketones', 'Ketone Bodies']),
    BiomarkerEntry(key: 'blood', standardName: 'Blood (Urine)', unit: '', aliases: ['Urine Blood', 'Occult Blood']),
    BiomarkerEntry(key: 'urobilinogen', standardName: 'Urobilinogen', unit: '', aliases: ['Urine Urobilinogen']),
    BiomarkerEntry(key: 'nitrites', standardName: 'Nitrites', unit: '', aliases: ['Urine Nitrites', 'Nitrite']),
    BiomarkerEntry(key: 'wbc_pus_cells_hpf', standardName: 'WBC / Pus Cells', unit: '/HPF', aliases: ['Pus Cells', 'WBC (Urine)', 'Leucocytes']),
    BiomarkerEntry(key: 'rbc', standardName: 'RBC (Urine)', unit: '/HPF', aliases: ['Red Blood Cells (Urine)']),
    BiomarkerEntry(key: 'epithelial_cells_hpf', standardName: 'Epithelial Cells', unit: '/HPF', aliases: ['Ep. Cells', 'Squamous Epithelial Cells']),
    BiomarkerEntry(key: 'casts', standardName: 'Casts', unit: '/LPF', aliases: ['Urine Casts']),
    BiomarkerEntry(key: 'crystals', standardName: 'Crystals', unit: '', aliases: ['Urine Crystals']),
  ];

  /// Normalize a string for comparison: lowercase, remove special chars.
  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Find the best matching BiomarkerEntry for a given test item name.
  /// Returns null if no confident match is found.
  static BiomarkerEntry? match(String testItem) {
    if (testItem.isEmpty) return null;
    final input = testItem.trim();
    final inputNorm = _normalize(input);
    if (inputNorm.isEmpty) return null;

    // 1. Exact match on key
    for (final e in entries) {
      if (e.key == input) return e;
    }

    // 2. Exact match on standardName (case-insensitive)
    for (final e in entries) {
      if (e.standardName.toLowerCase() == input.toLowerCase()) return e;
    }

    // 3. Alias match (case-insensitive)
    for (final e in entries) {
      for (final alias in e.aliases) {
        if (alias.toLowerCase() == input.toLowerCase()) return e;
      }
    }

    // 4. Normalized containment match (both directions)
    BiomarkerEntry? bestMatch;
    int bestScore = 0;
    for (final e in entries) {
      final nameNorm = _normalize(e.standardName);
      int score = 0;
      if (nameNorm == inputNorm) {
        score = 100;
      } else if (nameNorm.contains(inputNorm) && inputNorm.length >= 3) {
        score = 70 + inputNorm.length;
      } else if (inputNorm.contains(nameNorm) && nameNorm.length >= 3) {
        score = 60 + nameNorm.length;
      }
      // Also check aliases normalized
      for (final alias in e.aliases) {
        final aliasNorm = _normalize(alias);
        if (aliasNorm == inputNorm) {
          score = 100;
        } else if (aliasNorm.contains(inputNorm) && inputNorm.length >= 3 && score < 65) {
          score = 65;
        } else if (inputNorm.contains(aliasNorm) && aliasNorm.length >= 3 && score < 55) {
          score = 55;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = e;
      }
    }

    // Only return if we have a reasonable confidence
    return bestScore >= 55 ? bestMatch : null;
  }

  /// Get autocomplete suggestions for a partial input.
  static List<BiomarkerEntry> suggest(String partial) {
    if (partial.trim().length < 2) return [];
    final norm = _normalize(partial);
    final results = <BiomarkerEntry>[];
    for (final e in entries) {
      if (_normalize(e.standardName).contains(norm)) {
        results.add(e);
      } else if (e.aliases.any((a) => _normalize(a).contains(norm))) {
        results.add(e);
      }
      if (results.length >= 8) break;
    }
    return results;
  }
}
