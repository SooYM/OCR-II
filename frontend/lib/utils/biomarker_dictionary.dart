/// Standard biomarker data dictionary with fuzzy matching.
class BiomarkerEntry {
  final String key;
  final String standardName;
  final String unit;
  final String? referenceRange;
  final List<String> aliases;

  final String? description;

  const BiomarkerEntry({
    required this.key,
    required this.standardName,
    required this.unit,
    this.referenceRange,
    this.aliases = const [],
    this.description,
  });
}

class BiomarkerDictionary {
  static const Map<String, List<String>> medicalCategories = {
    'Urine': [
      'urine_colour', 'appearance', 'specific_gravity', 'ph', 'proteins', 'glucose', 
      'bilirubin', 'ketones', 'blood', 'urobilinogen', 'nitrites', 'wbc_pus_cells_hpf', 
      'rbc', 'epithelial_cells_hpf', 'casts', 'crystals', 'others'
    ],
    'CBC': [
      'hemoglobin_g_dl', 'rbc_count_mil_ul', 'hematocrit_pct', 'mcv_fl', 'mch_pg', 
      'mchc_g_dl', 'rdw_cv_pct', 'rdw_sd_fl', 'wbc_cells_ul', 'neutrophils_pct', 
      'lymphocytes_pct', 'eosinophils_pct', 'monocytes_pct', 'basophils_pct', 
      'abs_neutrophils', 'abs_lymphocytes', 'abs_monocytes', 'abs_eosinophils', 'abs_basophils'
    ],
    'Platelet Profile': [
      'platelet_count_x10_3_ul', 'mpv_fl', 'platelet_rdw_pct', 'pct_pct', 'p_lcr_pct', 
      'img_pct', 'imm_pct', 'iml_pct', 'lic_pct'
    ],
    'Lipid Profile': [
      'total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl', 'triglycerides_mg_dl', 
      'non_hdl_mg_dl', 'total_hdl_ratio', 'ldl_hdl_ratio', 'hdl_ldl_ratio'
    ],
    'Liver Function': [
      'bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl', 'alp_u_l', 
      'alt_sgpt_u_l', 'ast_sgot_u_l', 'ggt_u_l', 'protein_total_g_dl', 'albumin_g_dl', 
      'globulin_g_dl', 'a_g_ratio'
    ],
    'Kidney Function': [
      'creatinine_mg_dl', 'urea_mg_dl', 'bun_mg_dl', 'bun_creatinine_ratio', 'sodium_mmol_l', 
      'potassium_mmol_l', 'chloride_mmol_l', 'uric_acid_mg_dl', 'egfr_ml_min_173m2'
    ],
    'Iron Profile': [
      'iron_ug_dl', 'uibc_ug_dl', 'tibc_ug_dl', 'transferrin_saturation_pct'
    ],
    'HbA1c': [
      'hba1c_pct', 'estimated_avg_glucose_mg_dl', 'hbf_pct'
    ],
    'Urine ACR': [
      'urine_albumin_mg_l', 'urine_creatinine_mg_dl', 'albumin_creatinine_ratio'
    ],
    'Calcium & Phos': [
      'calcium_mg_dl', 'phosphorus_mg_dl'
    ],
    'Thyroid Profile': [
      'tt3_ng_dl', 'tt4_ug_dl', 'tsh_uiu_ml'
    ],
    'Glucose - Fasting': [
      'fasting_glucose_mg_dl'
    ],
    'Glucose - PP': [
      'postprandial_glucose_mg_dl'
    ],
    'Glucose (Diagnopath)': [
      'fbs_mg_dl', 'plbs_mg_dl'
    ],
  };

  static const List<BiomarkerEntry> entries = [
    // ─── CBC ──────────────────────────────────────────────
    BiomarkerEntry(key: 'hemoglobin_g_dl', standardName: 'Hemoglobin', unit: 'g/dL', referenceRange: '12.0 - 17.5', aliases: ['Hb', 'Haemoglobin', 'HGB', 'Hgb'], description: 'The protein in red blood cells that carries oxygen throughout the body.'),
    BiomarkerEntry(key: 'rbc_count_mil_ul', standardName: 'RBC Count', unit: 'mil/uL', referenceRange: '4.5 - 5.5', aliases: ['Red Blood Cell Count', 'RBC', 'Erythrocyte Count'], description: 'The total number of red blood cells in a volume of blood.'),
    BiomarkerEntry(key: 'hematocrit_pct', standardName: 'Hematocrit', unit: '%', referenceRange: '36 - 50', aliases: ['HCT', 'Haematocrit', 'PCV', 'Packed Cell Volume'], description: 'The proportion of blood that consists of red blood cells.'),
    BiomarkerEntry(key: 'mcv_fl', standardName: 'MCV', unit: 'fL', referenceRange: '80 - 100', aliases: ['Mean Corpuscular Volume'], description: 'The average size of your red blood cells.'),
    BiomarkerEntry(key: 'mch_pg', standardName: 'MCH', unit: 'pg', referenceRange: '27 - 33', aliases: ['Mean Corpuscular Hemoglobin', 'Mean Corpuscular Haemoglobin'], description: 'The average amount of hemoglobin in each red blood cell.'),
    BiomarkerEntry(key: 'mchc_g_dl', standardName: 'MCHC', unit: 'g/dL', referenceRange: '32 - 36', aliases: ['Mean Corpuscular Hemoglobin Concentration'], description: 'The average concentration of hemoglobin in a given volume of red blood cells.'),
    BiomarkerEntry(key: 'rdw_cv_pct', standardName: 'RDW-CV', unit: '%', referenceRange: '11.5 - 14.5', aliases: ['RDW', 'Red Cell Distribution Width'], description: 'A measure of the variation in size of red blood cells.'),
    BiomarkerEntry(key: 'rdw_sd_fl', standardName: 'RDW-SD', unit: 'fL', referenceRange: '35 - 56', aliases: [], description: 'The actual measurement of the width of the red blood cell distribution curve.'),
    BiomarkerEntry(key: 'wbc_cells_ul', standardName: 'WBC', unit: 'cells/uL', referenceRange: '4000 - 11000', aliases: ['White Blood Cell Count', 'TLC', 'Total Leucocyte Count', 'Total Leukocyte Count', 'Leucocyte Count'], description: 'The total number of white blood cells, which help the body fight infections.'),
    BiomarkerEntry(key: 'neutrophils_pct', standardName: 'Neutrophils', unit: '%', referenceRange: '40 - 70', aliases: ['Neutrophil', 'Neut', 'Segmented Neutrophils'], description: 'The most common type of white blood cell, primarily responsible for fighting bacterial infections.'),
    BiomarkerEntry(key: 'lymphocytes_pct', standardName: 'Lymphocytes', unit: '%', referenceRange: '20 - 40', aliases: ['Lymphocyte', 'Lymph'], description: 'White blood cells that are key to the immune system, including T cells and B cells.'),
    BiomarkerEntry(key: 'eosinophils_pct', standardName: 'Eosinophils', unit: '%', referenceRange: '1 - 6', aliases: ['Eosinophil', 'Eosino', 'Eos'], description: 'White blood cells active during allergic reactions and parasitic infections.'),
    BiomarkerEntry(key: 'monocytes_pct', standardName: 'Monocytes', unit: '%', referenceRange: '2 - 10', aliases: ['Monocyte', 'Mono'], description: 'White blood cells that migrate to tissues and become macrophages to consume pathogens.'),
    BiomarkerEntry(key: 'basophils_pct', standardName: 'Basophils', unit: '%', referenceRange: '0 - 2', aliases: ['Basophil', 'Baso'], description: 'The least common white blood cell, involved in inflammatory and allergic responses.'),
    BiomarkerEntry(key: 'abs_neutrophils', standardName: 'Abs. Neutrophils', unit: 'cells/uL', referenceRange: '2000 - 7000', aliases: ['ANC', 'Absolute Neutrophil Count'], description: 'The actual number of neutrophils present in the blood.'),
    BiomarkerEntry(key: 'abs_lymphocytes', standardName: 'Abs. Lymphocytes', unit: 'cells/uL', referenceRange: '1000 - 3000', aliases: ['ALC', 'Absolute Lymphocyte Count'], description: 'The actual number of lymphocytes present in the blood.'),
    BiomarkerEntry(key: 'abs_monocytes', standardName: 'Abs. Monocytes', unit: 'cells/uL', aliases: ['Absolute Monocyte Count'], description: 'The actual number of monocytes present in the blood.'),
    BiomarkerEntry(key: 'abs_eosinophils', standardName: 'Abs. Eosinophils', unit: 'cells/uL', aliases: ['AEC', 'Absolute Eosinophil Count'], description: 'The actual number of eosinophils present in the blood.'),
    BiomarkerEntry(key: 'abs_basophils', standardName: 'Abs. Basophils', unit: 'cells/uL', aliases: ['Absolute Basophil Count'], description: 'The actual number of basophils present in the blood.'),

    // ─── Platelet ─────────────────────────────────────────
    BiomarkerEntry(key: 'platelet_count_x10_3_ul', standardName: 'Platelet Count', unit: 'x10³/uL', referenceRange: '150 - 400', aliases: ['PLT', 'Platelets', 'Thrombocyte Count'], description: 'Cells that help the blood clot to stop bleeding.'),
    BiomarkerEntry(key: 'mpv_fl', standardName: 'MPV', unit: 'fL', referenceRange: '7.5 - 11.5', aliases: ['Mean Platelet Volume'], description: 'The average size of the platelets in your blood.'),
    BiomarkerEntry(key: 'platelet_rdw_pct', standardName: 'Platelet RDW', unit: '%', aliases: ['PDW', 'Platelet Distribution Width'], description: 'Measurement of how much platelets vary in size.'),
    BiomarkerEntry(key: 'pct_pct', standardName: 'PCT', unit: '%', aliases: ['Plateletcrit'], description: 'The volume occupied by platelets in the blood.'),
    BiomarkerEntry(key: 'p_lcr_pct', standardName: 'P-LCR', unit: '%', aliases: ['Platelet Large Cell Ratio'], description: 'The percentage of large-sized platelets.'),
    BiomarkerEntry(key: 'img_pct', standardName: 'IMG', unit: '%', aliases: [], description: 'Immature Granulocyte percentage.'),
    BiomarkerEntry(key: 'imm_pct', standardName: 'IMM', unit: '%', aliases: [], description: 'Immature Monocyte percentage.'),
    BiomarkerEntry(key: 'iml_pct', standardName: 'IML', unit: '%', aliases: [], description: 'Immature Lymphocyte percentage.'),
    BiomarkerEntry(key: 'lic_pct', standardName: 'LIC', unit: '%', aliases: [], description: 'Large Immature Cell percentage.'),

    // ─── Lipid Profile ────────────────────────────────────
    BiomarkerEntry(key: 'total_cholesterol_mg_dl', standardName: 'Total Cholesterol', unit: 'mg/dL', referenceRange: '< 200', aliases: ['Cholesterol', 'Tot. Cholesterol', 'TC', 'Chol', 'S. Cholesterol', 'Serum Cholesterol'], description: 'The total amount of cholesterol found in your blood.'),
    BiomarkerEntry(key: 'hdl_mg_dl', standardName: 'HDL Cholesterol', unit: 'mg/dL', referenceRange: '> 40', aliases: ['HDL', 'HDL-C', 'High Density Lipoprotein'], description: "Known as 'good' cholesterol; it helps remove other forms of cholesterol from your bloodstream."),
    BiomarkerEntry(key: 'ldl_mg_dl', standardName: 'LDL Cholesterol', unit: 'mg/dL', referenceRange: '< 100', aliases: ['LDL', 'LDL-C', 'Low Density Lipoprotein'], description: "Known as 'bad' cholesterol; high levels can lead to plaque buildup in arteries."),
    BiomarkerEntry(key: 'vldl_mg_dl', standardName: 'VLDL Cholesterol', unit: 'mg/dL', referenceRange: '< 30', aliases: ['VLDL', 'VLDL-C', 'Very Low Density Lipoprotein'], description: 'A type of blood fat that carries triglycerides.'),
    BiomarkerEntry(key: 'triglycerides_mg_dl', standardName: 'Triglycerides', unit: 'mg/dL', referenceRange: '< 150', aliases: ['TG', 'Trigs', 'Triglyceride', 'S. Triglycerides'], description: 'A type of fat (lipid) found in your blood, used for energy.'),
    BiomarkerEntry(key: 'non_hdl_mg_dl', standardName: 'Non-HDL Cholesterol', unit: 'mg/dL', aliases: ['Non HDL', 'Non-HDL'], description: 'Total cholesterol minus HDL; represents all potentially harmful cholesterol.'),
    BiomarkerEntry(key: 'total_hdl_ratio', standardName: 'Total/HDL Ratio', unit: '', aliases: ['TC/HDL', 'Cholesterol/HDL Ratio'], description: 'The ratio of total cholesterol to HDL, used to assess heart disease risk.'),
    BiomarkerEntry(key: 'ldl_hdl_ratio', standardName: 'LDL/HDL Ratio', unit: '', aliases: [], description: 'The ratio of LDL to HDL cholesterol.'),
    BiomarkerEntry(key: 'hdl_ldl_ratio', standardName: 'HDL/LDL Ratio', unit: '', aliases: [], description: 'The ratio of HDL to LDL cholesterol.'),

    // ─── Liver Function ───────────────────────────────────
    BiomarkerEntry(key: 'bilirubin_total_mg_dl', standardName: 'Bilirubin Total', unit: 'mg/dL', referenceRange: '0.1 - 1.2', aliases: ['Total Bilirubin', 'T. Bilirubin', 'S. Bilirubin'], description: 'A yellow pigment produced during the normal breakdown of red blood cells.'),
    BiomarkerEntry(key: 'bilirubin_direct_mg_dl', standardName: 'Bilirubin Direct', unit: 'mg/dL', referenceRange: '0.0 - 0.3', aliases: ['Direct Bilirubin', 'Conjugated Bilirubin'], description: 'Bilirubin that has been processed by the liver and is ready for excretion.'),
    BiomarkerEntry(key: 'bilirubin_indirect_mg_dl', standardName: 'Bilirubin Indirect', unit: 'mg/dL', referenceRange: '0.1 - 1.0', aliases: ['Indirect Bilirubin', 'Unconjugated Bilirubin'], description: 'Bilirubin that has not yet been processed by the liver.'),
    BiomarkerEntry(key: 'alp_u_l', standardName: 'ALP', unit: 'U/L', referenceRange: '44 - 147', aliases: ['Alkaline Phosphatase', 'Alk. Phosphatase'], description: 'An enzyme found in the liver, bones, kidneys, and digestive system.'),
    BiomarkerEntry(key: 'alt_sgpt_u_l', standardName: 'ALT (SGPT)', unit: 'U/L', referenceRange: '7 - 56', aliases: ['ALT', 'SGPT', 'Alanine Aminotransferase', 'Alanine Transaminase'], description: 'An enzyme found mostly in the liver; high levels suggest liver damage.'),
    BiomarkerEntry(key: 'ast_sgot_u_l', standardName: 'AST (SGOT)', unit: 'U/L', referenceRange: '10 - 40', aliases: ['AST', 'SGOT', 'Aspartate Aminotransferase', 'Aspartate Transaminase'], description: 'An enzyme found in the liver, heart, and muscles.'),
    BiomarkerEntry(key: 'ggt_u_l', standardName: 'GGT', unit: 'U/L', referenceRange: '9 - 48', aliases: ['Gamma GT', 'Gamma Glutamyl Transferase', 'Gamma-Glutamyl Transpeptidase'], description: 'An enzyme found in the liver and bile ducts; sensitive to alcohol and bile duct issues.'),
    BiomarkerEntry(key: 'protein_total_g_dl', standardName: 'Total Protein', unit: 'g/dL', referenceRange: '6.0 - 8.3', aliases: ['Protein Total', 'S. Protein', 'Serum Protein', 'Total Proteins'], description: 'The total amount of albumin and globulin in the blood.'),
    BiomarkerEntry(key: 'albumin_g_dl', standardName: 'Albumin', unit: 'g/dL', referenceRange: '3.5 - 5.5', aliases: ['S. Albumin', 'Serum Albumin', 'Alb'], description: 'A protein made by the liver that keeps fluid from leaking out of blood vessels.'),
    BiomarkerEntry(key: 'globulin_g_dl', standardName: 'Globulin', unit: 'g/dL', referenceRange: '2.0 - 3.5', aliases: ['S. Globulin', 'Serum Globulin'], description: 'A group of proteins in the blood that help the immune system and liver function.'),
    BiomarkerEntry(key: 'a_g_ratio', standardName: 'A/G Ratio', unit: '', referenceRange: '1.1 - 2.5', aliases: ['Albumin/Globulin Ratio', 'AG Ratio'], description: 'The ratio of albumin to globulin in the blood.'),

    // ─── Kidney Function ──────────────────────────────────
    BiomarkerEntry(key: 'creatinine_mg_dl', standardName: 'Creatinine', unit: 'mg/dL', referenceRange: '0.7 - 1.3', aliases: ['S. Creatinine', 'Serum Creatinine', 'Creat'], description: 'A waste product from muscle breakdown, filtered by the kidneys.'),
    BiomarkerEntry(key: 'urea_mg_dl', standardName: 'Urea', unit: 'mg/dL', referenceRange: '15 - 40', aliases: ['Blood Urea', 'S. Urea', 'Serum Urea'], description: 'A waste product formed in the liver when protein is broken down.'),
    BiomarkerEntry(key: 'bun_mg_dl', standardName: 'BUN', unit: 'mg/dL', referenceRange: '7 - 20', aliases: ['Blood Urea Nitrogen'], description: 'The amount of nitrogen in your blood that comes from the waste product urea.'),
    BiomarkerEntry(key: 'bun_creatinine_ratio', standardName: 'BUN/Creatinine Ratio', unit: '', aliases: [], description: 'The ratio of BUN to creatinine, used to diagnose acute kidney issues.'),
    BiomarkerEntry(key: 'sodium_mmol_l', standardName: 'Sodium', unit: 'mmol/L', referenceRange: '136 - 145', aliases: ['Na', 'Na+', 'S. Sodium', 'Serum Sodium'], description: 'An electrolyte that helps maintain fluid balance and nerve function.'),
    BiomarkerEntry(key: 'potassium_mmol_l', standardName: 'Potassium', unit: 'mmol/L', referenceRange: '3.5 - 5.1', aliases: ['K', 'K+', 'S. Potassium', 'Serum Potassium'], description: 'An electrolyte vital for heart and muscle function.'),
    BiomarkerEntry(key: 'chloride_mmol_l', standardName: 'Chloride', unit: 'mmol/L', referenceRange: '98 - 106', aliases: ['Cl', 'Cl-', 'S. Chloride', 'Serum Chloride'], description: 'An electrolyte that helps maintain proper blood volume and pressure.'),
    BiomarkerEntry(key: 'uric_acid_mg_dl', standardName: 'Uric Acid', unit: 'mg/dL', referenceRange: '3.5 - 7.2', aliases: ['S. Uric Acid', 'Serum Uric Acid'], description: 'A waste product from the breakdown of purines; high levels can cause gout.'),
    BiomarkerEntry(key: 'egfr_ml_min_173m2', standardName: 'eGFR', unit: 'mL/min/1.73m²', referenceRange: '> 90', aliases: ['Estimated GFR', 'Glomerular Filtration Rate'], description: 'A calculation of how well the kidneys are filtering waste from the blood.'),

    // ─── Iron Profile ─────────────────────────────────────
    BiomarkerEntry(key: 'iron_ug_dl', standardName: 'Iron', unit: 'ug/dL', referenceRange: '60 - 170', aliases: ['S. Iron', 'Serum Iron', 'Fe'], description: 'A mineral used by the body to make hemoglobin.'),
    BiomarkerEntry(key: 'uibc_ug_dl', standardName: 'UIBC', unit: 'ug/dL', aliases: ['Unsaturated Iron Binding Capacity'], description: 'The reserve capacity of transferrin to bind iron.'),
    BiomarkerEntry(key: 'tibc_ug_dl', standardName: 'TIBC', unit: 'ug/dL', referenceRange: '250 - 370', aliases: ['Total Iron Binding Capacity'], description: 'The total capacity of the blood to carry iron.'),
    BiomarkerEntry(key: 'transferrin_saturation_pct', standardName: 'Transferrin Saturation', unit: '%', referenceRange: '20 - 50', aliases: ['TSAT', 'Iron Saturation'], description: 'The percentage of transferrin that is saturated with iron.'),

    // ─── HbA1c ────────────────────────────────────────────
    BiomarkerEntry(key: 'hba1c_pct', standardName: 'HbA1c', unit: '%', referenceRange: '< 5.7', aliases: ['Glycated Hemoglobin', 'Glycosylated Hemoglobin', 'A1C', 'Glycated Haemoglobin'], description: 'Measures average blood sugar levels over the past 2-3 months.'),
    BiomarkerEntry(key: 'estimated_avg_glucose_mg_dl', standardName: 'Estimated Avg. Glucose', unit: 'mg/dL', aliases: ['eAG', 'Estimated Average Glucose'], description: 'A calculated average of blood glucose based on HbA1c results.'),
    BiomarkerEntry(key: 'hbf_pct', standardName: 'HbF', unit: '%', aliases: ['Fetal Hemoglobin'], description: 'A form of hemoglobin that is normal in infants but low in adults.'),

    // ─── Urine ACR ────────────────────────────────────────
    BiomarkerEntry(key: 'urine_albumin_mg_l', standardName: 'Urine Albumin', unit: 'mg/L', aliases: ['Microalbumin', 'U. Albumin'], description: 'Small amounts of albumin in the urine, an early sign of kidney disease.'),
    BiomarkerEntry(key: 'urine_creatinine_mg_dl', standardName: 'Urine Creatinine', unit: 'mg/dL', aliases: ['U. Creatinine'], description: 'Creatinine measured in a urine sample.'),
    BiomarkerEntry(key: 'albumin_creatinine_ratio', standardName: 'Albumin/Creatinine Ratio', unit: '', referenceRange: '< 30', aliases: ['ACR', 'Urine ACR'], description: 'The ratio of albumin to creatinine in the urine, used to detect kidney damage.'),

    // ─── Calcium & Phosphorus ─────────────────────────────
    BiomarkerEntry(key: 'calcium_mg_dl', standardName: 'Calcium', unit: 'mg/dL', referenceRange: '8.5 - 10.5', aliases: ['Ca', 'Ca++', 'S. Calcium', 'Serum Calcium', 'Total Calcium'], description: 'Important for bone health, muscle function, and nerve signaling.'),
    BiomarkerEntry(key: 'phosphorus_mg_dl', standardName: 'Phosphorus', unit: 'mg/dL', referenceRange: '2.5 - 4.5', aliases: ['Phosphate', 'Phos', 'S. Phosphorus', 'Inorganic Phosphorus'], description: 'A mineral that works with calcium to build bones and teeth.'),

    // ─── Thyroid Profile ──────────────────────────────────
    BiomarkerEntry(key: 'tt3_ng_dl', standardName: 'Total T3', unit: 'ng/dL', referenceRange: '80 - 200', aliases: ['T3', 'TT3', 'Triiodothyronine'], description: 'One of the two main hormones produced by the thyroid gland.'),
    BiomarkerEntry(key: 'tt4_ug_dl', standardName: 'Total T4', unit: 'ug/dL', referenceRange: '5.1 - 14.1', aliases: ['T4', 'TT4', 'Thyroxine'], description: 'The main hormone produced by the thyroid gland.'),
    BiomarkerEntry(key: 'tsh_uiu_ml', standardName: 'TSH', unit: 'uIU/mL', referenceRange: '0.4 - 4.0', aliases: ['Thyroid Stimulating Hormone', 'Thyrotropin'], description: 'Hormone from the pituitary gland that tells the thyroid to make T3 and T4.'),

    // ─── Glucose ──────────────────────────────────────────
    BiomarkerEntry(key: 'fasting_glucose_mg_dl', standardName: 'Fasting Glucose', unit: 'mg/dL', referenceRange: '70 - 100', aliases: ['FBS', 'Fasting Blood Sugar', 'Fasting Blood Glucose', 'Glucose Fasting', 'F. Glucose'], description: 'Blood sugar level measured after an 8-12 hour fast.'),
    BiomarkerEntry(key: 'postprandial_glucose_mg_dl', standardName: 'Postprandial Glucose', unit: 'mg/dL', referenceRange: '< 140', aliases: ['PPBS', 'PP Blood Sugar', 'PP Glucose', 'Post Prandial Blood Sugar', 'Glucose PP'], description: 'Blood sugar level measured 2 hours after a meal.'),
    BiomarkerEntry(key: 'fbs_mg_dl', standardName: 'FBS', unit: 'mg/dL', referenceRange: '70 - 100', aliases: ['Fasting Blood Sugar'], description: 'Fasting Blood Sugar (Diagnostic specific).'),
    BiomarkerEntry(key: 'plbs_mg_dl', standardName: 'PLBS', unit: 'mg/dL', referenceRange: '< 140', aliases: ['Post Lunch Blood Sugar'], description: 'Post Lunch Blood Sugar (Diagnostic specific).'),

    // ─── Urinalysis ───────────────────────────────────────
    BiomarkerEntry(key: 'urine_colour', standardName: 'Urine Colour', unit: '', aliases: ['Urine Color', 'Colour'], description: 'The visual color of the urine sample.'),
    BiomarkerEntry(key: 'appearance', standardName: 'Appearance', unit: '', aliases: ['Urine Appearance'], description: 'The clarity or turbidity of the urine.'),
    BiomarkerEntry(key: 'specific_gravity', standardName: 'Specific Gravity', unit: '', referenceRange: '1.005 - 1.030', aliases: ['Sp. Gravity', 'SG'], description: 'Measures the concentration of particles in the urine.'),
    BiomarkerEntry(key: 'ph', standardName: 'pH', unit: '', referenceRange: '4.5 - 8.0', aliases: ['Urine pH'], description: 'Measures the acidity or alkalinity of the urine.'),
    BiomarkerEntry(key: 'proteins', standardName: 'Proteins', unit: '', aliases: ['Urine Protein', 'Protein'], description: 'Detects the presence of protein in the urine.'),
    BiomarkerEntry(key: 'glucose', standardName: 'Glucose (Urine)', unit: '', aliases: ['Urine Glucose', 'Sugar'], description: 'Detects the presence of sugar in the urine.'),
    BiomarkerEntry(key: 'bilirubin', standardName: 'Bilirubin (Urine)', unit: '', aliases: ['Urine Bilirubin'], description: 'Detects processed bilirubin in the urine.'),
    BiomarkerEntry(key: 'ketones', standardName: 'Ketones', unit: '', aliases: ['Urine Ketones', 'Ketone Bodies'], description: 'Detects ketones, a byproduct of fat breakdown.'),
    BiomarkerEntry(key: 'blood', standardName: 'Blood (Urine)', unit: '', aliases: ['Urine Blood', 'Occult Blood'], description: 'Detects the presence of blood or hemoglobin in the urine.'),
    BiomarkerEntry(key: 'urobilinogen', standardName: 'Urobilinogen', unit: '', aliases: ['Urine Urobilinogen'], description: 'A byproduct of bilirubin breakdown found in urine.'),
    BiomarkerEntry(key: 'nitrites', standardName: 'Nitrites', unit: '', aliases: ['Urine Nitrites', 'Nitrite'], description: 'Often indicates the presence of a urinary tract infection (UTI).'),
    BiomarkerEntry(key: 'wbc_pus_cells_hpf', standardName: 'WBC / Pus Cells', unit: '/HPF', aliases: ['Pus Cells', 'WBC (Urine)', 'Leucocytes'], description: 'Presence of white blood cells in urine, indicating infection or inflammation.'),
    BiomarkerEntry(key: 'rbc', standardName: 'RBC (Urine)', unit: '/HPF', aliases: ['Red Blood Cells (Urine)'], description: 'Presence of red blood cells in urine.'),
    BiomarkerEntry(key: 'epithelial_cells_hpf', standardName: 'Epithelial Cells', unit: '/HPF', aliases: ['Ep. Cells', 'Squamous Epithelial Cells'], description: 'Cells that line the urinary tract.'),
    BiomarkerEntry(key: 'casts', standardName: 'Casts', unit: '/LPF', aliases: ['Urine Casts'], description: 'Cylindrical structures formed in the kidney tubules.'),
    BiomarkerEntry(key: 'crystals', standardName: 'Crystals', unit: '', aliases: ['Urine Crystals'], description: 'Solid particles formed from chemicals in the urine.'),
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
