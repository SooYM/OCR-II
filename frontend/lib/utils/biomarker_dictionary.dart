/// Standard biomarker data dictionary with fuzzy matching.
class BiomarkerEntry {
  final String key;
  final String standardName;
  final String unit;
  final String? referenceRange;
  final String? referenceRangeSI;
  final List<String> aliases;
  final List<String> allowedUnits;
  final String? description;

  const BiomarkerEntry({
    required this.key,
    required this.standardName,
    required this.unit,
    this.referenceRange,
    this.referenceRangeSI,
    this.aliases = const [],
    this.allowedUnits = const [],
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
      'non_hdl_mg_dl', 'total_hdl_ratio', 'ldl_hdl_ratio'
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
    // ─── Urinalysis ───────────────────────────────────────
    BiomarkerEntry(
      key: 'urine_colour',
      standardName: 'Urine Colour',
      unit: '',
      referenceRange: 'Pale yellow to amber',
      referenceRangeSI: 'N/A',
      aliases: ['Urine Color', 'Colour'],
      description: 'The visual color of the urine sample.',
    ),
    BiomarkerEntry(
      key: 'appearance',
      standardName: 'Appearance',
      unit: '',
      referenceRange: 'Clear',
      referenceRangeSI: 'N/A',
      aliases: ['Urine Appearance'],
      description: 'The clarity or turbidity of the urine.',
    ),
    BiomarkerEntry(
      key: 'specific_gravity',
      standardName: 'Specific Gravity',
      unit: '',
      referenceRange: '1.005 - 1.030',
      referenceRangeSI: 'N/A',
      aliases: ['Sp. Gravity', 'SG'],
      description: 'Measures the concentration of particles in the urine.',
    ),
    BiomarkerEntry(
      key: 'ph',
      standardName: 'pH',
      unit: '',
      referenceRange: '4.5 - 8.0',
      referenceRangeSI: 'N/A',
      aliases: ['Urine pH'],
      description: 'Measures the acidity or alkalinity of the urine.',
    ),
    BiomarkerEntry(
      key: 'proteins',
      standardName: 'Proteins',
      unit: 'mg/dL',
      referenceRange: 'Negative or < 15 mg/dL',
      referenceRangeSI: 'Negative or < 0.15 g/L',
      allowedUnits: ['mg/dL', 'g/L'],
      aliases: ['Urine Protein', 'Protein'],
      description: 'Detects the presence of protein in the urine.',
    ),
    BiomarkerEntry(
      key: 'glucose',
      standardName: 'Glucose (Urine)',
      unit: '',
      referenceRange: 'Negative',
      referenceRangeSI: 'Negative',
      aliases: ['Urine Glucose', 'Sugar'],
      description: 'Detects the presence of sugar in the urine.',
    ),
    BiomarkerEntry(
      key: 'bilirubin',
      standardName: 'Bilirubin (Urine)',
      unit: '',
      referenceRange: 'Negative',
      referenceRangeSI: 'Negative',
      aliases: ['Urine Bilirubin'],
      description: 'Detects processed bilirubin in the urine.',
    ),
    BiomarkerEntry(
      key: 'ketones',
      standardName: 'Ketones',
      unit: '',
      referenceRange: 'Negative',
      referenceRangeSI: 'Negative',
      aliases: ['Urine Ketones', 'Ketone Bodies'],
      description: 'Detects ketones, a byproduct of fat breakdown.',
    ),
    BiomarkerEntry(
      key: 'blood',
      standardName: 'Blood (Urine)',
      unit: '',
      referenceRange: 'Negative',
      referenceRangeSI: 'Negative',
      aliases: ['Urine Blood', 'Occult Blood'],
      description: 'Detects the presence of blood or hemoglobin in the urine.',
    ),
    BiomarkerEntry(
      key: 'urobilinogen',
      standardName: 'Urobilinogen',
      unit: 'EU/dL',
      referenceRange: '0.2 - 1.0 EU/dL or Normal',
      referenceRangeSI: '3.4 - 17.0 µmol/L',
      allowedUnits: ['EU/dL', 'µmol/L'],
      aliases: ['Urine Urobilinogen'],
      description: 'A byproduct of bilirubin breakdown found in urine.',
    ),
    BiomarkerEntry(
      key: 'nitrites',
      standardName: 'Nitrites',
      unit: '',
      referenceRange: 'Negative',
      referenceRangeSI: 'Negative',
      aliases: ['Urine Nitrites', 'Nitrite'],
      description: 'Often indicates the presence of a urinary tract infection (UTI).',
    ),
    BiomarkerEntry(
      key: 'wbc_pus_cells_hpf',
      standardName: 'WBC / Pus Cells',
      unit: '/HPF',
      referenceRange: '0 - 5 /HPF',
      referenceRangeSI: '0 - 5 x 10^6/L',
      allowedUnits: ['/HPF', 'x10^6/L'],
      aliases: ['Pus Cells', 'WBC (Urine)', 'Leucocytes'],
      description: 'Presence of white blood cells in urine, indicating infection or inflammation.',
    ),
    BiomarkerEntry(
      key: 'rbc',
      standardName: 'RBC (Urine)',
      unit: '/HPF',
      referenceRange: '0 - 2 /HPF',
      referenceRangeSI: '0 - 2 x 10^6/L',
      allowedUnits: ['/HPF', 'x10^6/L'],
      aliases: ['Red Blood Cells (Urine)'],
      description: 'Presence of red blood cells in urine.',
    ),
    BiomarkerEntry(
      key: 'epithelial_cells_hpf',
      standardName: 'Epithelial Cells',
      unit: '/HPF',
      referenceRange: '0 - 5 /HPF',
      referenceRangeSI: '0 - 5 x 10^6/L',
      allowedUnits: ['/HPF', 'x10^6/L'],
      aliases: ['Ep. Cells', 'Squamous Epithelial Cells'],
      description: 'Cells that line the urinary tract.',
    ),
    BiomarkerEntry(
      key: 'casts',
      standardName: 'Casts',
      unit: '/LPF',
      referenceRange: 'Negative',
      referenceRangeSI: 'Negative',
      allowedUnits: ['/LPF'],
      aliases: ['Urine Casts'],
      description: 'Cylindrical structures formed in the kidney tubules.',
    ),
    BiomarkerEntry(
      key: 'crystals',
      standardName: 'Crystals',
      unit: '',
      referenceRange: 'Negative',
      referenceRangeSI: 'Negative',
      aliases: ['Urine Crystals'],
      description: 'Solid particles formed from chemicals in the urine.',
    ),
    BiomarkerEntry(
      key: 'others',
      standardName: 'Others',
      unit: '',
      referenceRange: 'Negative / Nil',
      referenceRangeSI: 'Negative',
      aliases: ['Urine Others', 'Other'],
      description: 'Any other elements observed in urine.',
    ),

    // ─── CBC ──────────────────────────────────────────────
    BiomarkerEntry(
      key: 'hemoglobin_g_dl',
      standardName: 'Hemoglobin',
      unit: 'g/dL',
      referenceRange: 'Male: 13.8 - 17.2 g/dL | Female: 12.1 - 15.1 g/dL',
      referenceRangeSI: 'Male: 138 - 172 g/L | Female: 121 - 151 g/L',
      allowedUnits: ['g/dL', 'g/L'],
      aliases: ['Hb', 'Haemoglobin', 'HGB', 'Hgb'],
      description: 'The protein in red blood cells that carries oxygen throughout the body.',
    ),
    BiomarkerEntry(
      key: 'rbc_count_mil_ul',
      standardName: 'RBC Count',
      unit: 'mil/uL',
      referenceRange: 'Male: 4.5 - 5.9 mil/µL | Female: 4.1 - 5.1 mil/µL',
      referenceRangeSI: 'Male: 4.5 - 5.9 × 10^12/L | Female: 4.1 - 5.1 × 10^12/L',
      allowedUnits: ['mil/uL', '10^12/L'],
      aliases: ['Red Blood Cell Count', 'RBC', 'Erythrocyte Count'],
      description: 'The total number of red blood cells in a volume of blood.',
    ),
    BiomarkerEntry(
      key: 'hematocrit_pct',
      standardName: 'Hematocrit',
      unit: '%',
      referenceRange: 'Male: 40.7% - 50.3% | Female: 36.1% - 44.3%',
      referenceRangeSI: 'Male: 0.407 - 0.503 L/L | Female: 0.361 - 0.443 L/L',
      allowedUnits: ['%', 'fraction', 'L/L'],
      aliases: ['HCT', 'Haematocrit', 'PCV', 'Packed Cell Volume'],
      description: 'The proportion of blood that consists of red blood cells.',
    ),
    BiomarkerEntry(
      key: 'mcv_fl',
      standardName: 'MCV',
      unit: 'fL',
      referenceRange: '80 - 100 fL',
      referenceRangeSI: '80 - 100 fL',
      allowedUnits: ['fL'],
      aliases: ['Mean Corpuscular Volume'],
      description: 'The average size of your red blood cells.',
    ),
    BiomarkerEntry(
      key: 'mch_pg',
      standardName: 'MCH',
      unit: 'pg',
      referenceRange: '27 - 33 pg',
      referenceRangeSI: '27 - 33 pg',
      allowedUnits: ['pg'],
      aliases: ['Mean Corpuscular Hemoglobin', 'Mean Corpuscular Haemoglobin'],
      description: 'The average amount of hemoglobin in each red blood cell.',
    ),
    BiomarkerEntry(
      key: 'mchc_g_dl',
      standardName: 'MCHC',
      unit: 'g/dL',
      referenceRange: '32 - 36 g/dL',
      referenceRangeSI: '320 - 360 g/L',
      allowedUnits: ['g/dL', 'g/L'],
      aliases: ['Mean Corpuscular Hemoglobin Concentration'],
      description: 'The average concentration of hemoglobin in a given volume of red blood cells.',
    ),
    BiomarkerEntry(
      key: 'rdw_cv_pct',
      standardName: 'RDW-CV',
      unit: '%',
      referenceRange: '11.5% - 14.5%',
      referenceRangeSI: '0.115 - 0.145 fraction',
      allowedUnits: ['%'],
      aliases: ['RDW', 'Red Cell Distribution Width'],
      description: 'A measure of the variation in size of red blood cells.',
    ),
    BiomarkerEntry(
      key: 'rdw_sd_fl',
      standardName: 'RDW-SD',
      unit: 'fL',
      referenceRange: '39 - 46 fL',
      referenceRangeSI: '39 - 46 fL',
      allowedUnits: ['fL'],
      aliases: [],
      description: 'The actual measurement of the width of the red blood cell distribution curve.',
    ),
    BiomarkerEntry(
      key: 'wbc_cells_ul',
      standardName: 'WBC',
      unit: 'cells/uL',
      referenceRange: '4,000 - 11,000 cells/µL',
      referenceRangeSI: '4.0 - 11.0 × 10^9/L',
      allowedUnits: ['cells/uL', '10^9/L'],
      aliases: ['White Blood Cell Count', 'TLC', 'Total Leucocyte Count', 'Total Leukocyte Count', 'Leucocyte Count'],
      description: 'The total number of white blood cells, which help the body fight infections.',
    ),
    BiomarkerEntry(
      key: 'neutrophils_pct',
      standardName: 'Neutrophils',
      unit: '%',
      referenceRange: '40% - 60%',
      referenceRangeSI: '0.40 - 0.60 fraction',
      allowedUnits: ['%'],
      aliases: ['Neutrophil', 'Neut', 'Segmented Neutrophils'],
      description: 'The most common type of white blood cell, primarily responsible for fighting bacterial infections.',
    ),
    BiomarkerEntry(
      key: 'lymphocytes_pct',
      standardName: 'Lymphocytes',
      unit: '%',
      referenceRange: '20% - 40%',
      referenceRangeSI: '0.20 - 0.40 fraction',
      allowedUnits: ['%'],
      aliases: ['Lymphocyte', 'Lymph'],
      description: 'White blood cells that are key to the immune system, including T cells and B cells.',
    ),
    BiomarkerEntry(
      key: 'eosinophils_pct',
      standardName: 'Eosinophils',
      unit: '%',
      referenceRange: '1% - 4%',
      referenceRangeSI: '0.01 - 0.04 fraction',
      allowedUnits: ['%'],
      aliases: ['Eosinophil', 'Eosino', 'Eos'],
      description: 'White blood cells active during allergic reactions and parasitic infections.',
    ),
    BiomarkerEntry(
      key: 'monocytes_pct',
      standardName: 'Monocytes',
      unit: '%',
      referenceRange: '2% - 8%',
      referenceRangeSI: '0.02 - 0.08 fraction',
      allowedUnits: ['%'],
      aliases: ['Monocyte', 'Mono'],
      description: 'White blood cells that migrate to tissues and become macrophages to consume pathogens.',
    ),
    BiomarkerEntry(
      key: 'basophils_pct',
      standardName: 'Basophils',
      unit: '%',
      referenceRange: '0.5% - 1%',
      referenceRangeSI: '0.005 - 0.01 fraction',
      allowedUnits: ['%'],
      aliases: ['Basophil', 'Baso'],
      description: 'The least common white blood cell, involved in inflammatory and allergic responses.',
    ),
    BiomarkerEntry(
      key: 'abs_neutrophils',
      standardName: 'Abs. Neutrophils',
      unit: 'cells/uL',
      referenceRange: '1,500 - 8,000 cells/µL',
      referenceRangeSI: '1.5 - 8.0 × 10^9/L',
      allowedUnits: ['cells/uL', '10^9/L'],
      aliases: ['ANC', 'Absolute Neutrophil Count'],
      description: 'The actual number of neutrophils present in the blood.',
    ),
    BiomarkerEntry(
      key: 'abs_lymphocytes',
      standardName: 'Abs. Lymphocytes',
      unit: 'cells/uL',
      referenceRange: '1,000 - 4,800 cells/µL',
      referenceRangeSI: '1.0 - 4.8 × 10^9/L',
      allowedUnits: ['cells/uL', '10^9/L'],
      aliases: ['ALC', 'Absolute Lymphocyte Count'],
      description: 'The actual number of lymphocytes present in the blood.',
    ),
    BiomarkerEntry(
      key: 'abs_monocytes',
      standardName: 'Abs. Monocytes',
      unit: 'cells/uL',
      referenceRange: '200 - 1,000 cells/µL',
      referenceRangeSI: '0.2 - 1.0 × 10^9/L',
      allowedUnits: ['cells/uL', '10^9/L'],
      aliases: ['Absolute Monocyte Count'],
      description: 'The actual number of monocytes present in the blood.',
    ),
    BiomarkerEntry(
      key: 'abs_eosinophils',
      standardName: 'Abs. Eosinophils',
      unit: 'cells/uL',
      referenceRange: '0 - 500 cells/µL',
      referenceRangeSI: '0.0 - 0.5 × 10^9/L',
      allowedUnits: ['cells/uL', '10^9/L'],
      aliases: ['AEC', 'Absolute Eosinophil Count'],
      description: 'The actual number of eosinophils present in the blood.',
    ),
    BiomarkerEntry(
      key: 'abs_basophils',
      standardName: 'Abs. Basophils',
      unit: 'cells/uL',
      referenceRange: '0 - 200 cells/µL',
      referenceRangeSI: '0.0 - 0.2 × 10^9/L',
      allowedUnits: ['cells/uL', '10^9/L'],
      aliases: ['Absolute Basophil Count'],
      description: 'The actual number of basophils present in the blood.',
    ),

    // ─── Platelet Profile ─────────────────────────────────
    BiomarkerEntry(
      key: 'platelet_count_x10_3_ul',
      standardName: 'Platelet Count',
      unit: 'x10³/uL',
      referenceRange: '150 - 450 × 10^3/µL',
      referenceRangeSI: '150 - 450 × 10^9/L',
      allowedUnits: ['x10³/uL', '10^9/L'],
      aliases: ['PLT', 'Platelets', 'Thrombocyte Count'],
      description: 'Cells that help the blood clot to stop bleeding.',
    ),
    BiomarkerEntry(
      key: 'mpv_fl',
      standardName: 'MPV',
      unit: 'fL',
      referenceRange: '7.5 - 11.5 fL',
      referenceRangeSI: '7.5 - 11.5 fL',
      allowedUnits: ['fL'],
      aliases: ['Mean Platelet Volume'],
      description: 'The average size of the platelets in your blood.',
    ),
    BiomarkerEntry(
      key: 'platelet_rdw_pct',
      standardName: 'Platelet RDW',
      unit: '%',
      referenceRange: '9% - 17%',
      referenceRangeSI: '0.09 - 0.17 fraction',
      allowedUnits: ['%'],
      aliases: ['PDW', 'Platelet Distribution Width'],
      description: 'Measurement of how much platelets vary in size.',
    ),
    BiomarkerEntry(
      key: 'pct_pct',
      standardName: 'PCT',
      unit: '%',
      referenceRange: '0.17% - 0.35%',
      referenceRangeSI: '1.7 - 3.5 mL/L',
      allowedUnits: ['%'],
      aliases: ['Plateletcrit'],
      description: 'The volume occupied by platelets in the blood.',
    ),
    BiomarkerEntry(
      key: 'p_lcr_pct',
      standardName: 'P-LCR',
      unit: '%',
      referenceRange: '13% - 43%',
      referenceRangeSI: '0.13 - 0.43 fraction',
      allowedUnits: ['%'],
      aliases: ['Platelet Large Cell Ratio'],
      description: 'The percentage of large-sized platelets.',
    ),
    BiomarkerEntry(
      key: 'img_pct',
      standardName: 'IMG',
      unit: '%',
      referenceRange: '0% - 0.5%',
      referenceRangeSI: '0.0 - 0.005 fraction',
      allowedUnits: ['%'],
      aliases: [],
      description: 'Immature Granulocyte percentage.',
    ),
    BiomarkerEntry(
      key: 'imm_pct',
      standardName: 'IMM',
      unit: '%',
      referenceRange: '0% - 0.5%',
      referenceRangeSI: '0.0 - 0.005 fraction',
      allowedUnits: ['%'],
      aliases: [],
      description: 'Immature Monocyte percentage.',
    ),
    BiomarkerEntry(
      key: 'iml_pct',
      standardName: 'IML',
      unit: '%',
      referenceRange: '0% - 0.5%',
      referenceRangeSI: '0.0 - 0.005 fraction',
      allowedUnits: ['%'],
      aliases: [],
      description: 'Immature Lymphocyte percentage.',
    ),
    BiomarkerEntry(
      key: 'lic_pct',
      standardName: 'LIC',
      unit: '%',
      referenceRange: '0% - 2.5%',
      referenceRangeSI: '0.0 - 0.025 fraction',
      allowedUnits: ['%'],
      aliases: [],
      description: 'Large Immature Cell percentage.',
    ),

    // ─── Lipid Profile ────────────────────────────────────
    BiomarkerEntry(
      key: 'total_cholesterol_mg_dl',
      standardName: 'Total Cholesterol',
      unit: 'mg/dL',
      referenceRange: '< 200 mg/dL',
      referenceRangeSI: '< 5.17 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Cholesterol', 'Tot. Cholesterol', 'TC', 'Chol', 'S. Cholesterol', 'Serum Cholesterol'],
      description: 'The total amount of cholesterol found in your blood.',
    ),
    BiomarkerEntry(
      key: 'hdl_mg_dl',
      standardName: 'HDL Cholesterol',
      unit: 'mg/dL',
      referenceRange: '> 40 mg/dL Male | > 50 mg/dL Female',
      referenceRangeSI: '> 1.03 mmol/L Male | > 1.29 mmol/L Female',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['HDL', 'HDL-C', 'High Density Lipoprotein'],
      description: "Known as 'good' cholesterol; it helps remove other forms of cholesterol from your bloodstream.",
    ),
    BiomarkerEntry(
      key: 'ldl_mg_dl',
      standardName: 'LDL Cholesterol',
      unit: 'mg/dL',
      referenceRange: '< 100 mg/dL',
      referenceRangeSI: '< 2.59 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['LDL', 'LDL-C', 'Low Density Lipoprotein'],
      description: "Known as 'bad' cholesterol; high levels can lead to plaque buildup in arteries.",
    ),
    BiomarkerEntry(
      key: 'vldl_mg_dl',
      standardName: 'VLDL Cholesterol',
      unit: 'mg/dL',
      referenceRange: '2 - 30 mg/dL',
      referenceRangeSI: '0.05 - 0.78 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['VLDL', 'VLDL-C', 'Very Low Density Lipoprotein'],
      description: 'A type of blood fat that carries triglycerides.',
    ),
    BiomarkerEntry(
      key: 'triglycerides_mg_dl',
      standardName: 'Triglycerides',
      unit: 'mg/dL',
      referenceRange: '< 150 mg/dL',
      referenceRangeSI: '< 1.69 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['TG', 'Trigs', 'Triglyceride', 'S. Triglycerides'],
      description: 'A type of fat (lipid) found in your blood, used for energy.',
    ),
    BiomarkerEntry(
      key: 'non_hdl_mg_dl',
      standardName: 'Non-HDL Cholesterol',
      unit: 'mg/dL',
      referenceRange: '< 130 mg/dL',
      referenceRangeSI: '< 3.36 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Non HDL', 'Non-HDL'],
      description: 'Total cholesterol minus HDL; represents all potentially harmful cholesterol.',
    ),
    BiomarkerEntry(
      key: 'total_hdl_ratio',
      standardName: 'Total/HDL Ratio',
      unit: '',
      referenceRange: '< 5.0 (Optimal < 3.5)',
      referenceRangeSI: '< 5.0',
      aliases: ['TC/HDL', 'Cholesterol/HDL Ratio'],
      description: 'The ratio of total cholesterol to HDL, used to assess heart disease risk.',
    ),
    BiomarkerEntry(
      key: 'ldl_hdl_ratio',
      standardName: 'LDL/HDL Ratio',
      unit: '',
      referenceRange: '< 3.0',
      referenceRangeSI: '< 3.0',
      aliases: [],
      description: 'The ratio of LDL to HDL cholesterol.',
    ),
    // ─── Liver Function ───────────────────────────────────
    BiomarkerEntry(
      key: 'bilirubin_total_mg_dl',
      standardName: 'Bilirubin Total',
      unit: 'mg/dL',
      referenceRange: '0.1 - 1.2 mg/dL',
      referenceRangeSI: '1.7 - 20.5 µmol/L',
      allowedUnits: ['mg/dL', 'umol/L', 'µmol/L'],
      aliases: ['Total Bilirubin', 'T. Bilirubin', 'S. Bilirubin'],
      description: 'A yellow pigment produced during the normal breakdown of red blood cells.',
    ),
    BiomarkerEntry(
      key: 'bilirubin_direct_mg_dl',
      standardName: 'Bilirubin Direct',
      unit: 'mg/dL',
      referenceRange: '< 0.3 mg/dL',
      referenceRangeSI: '< 5.1 µmol/L',
      allowedUnits: ['mg/dL', 'umol/L', 'µmol/L'],
      aliases: ['Direct Bilirubin', 'Conjugated Bilirubin'],
      description: 'Bilirubin that has been processed by the liver and is ready for excretion.',
    ),
    BiomarkerEntry(
      key: 'bilirubin_indirect_mg_dl',
      standardName: 'Bilirubin Indirect',
      unit: 'mg/dL',
      referenceRange: '0.1 - 1.0 mg/dL',
      referenceRangeSI: '1.7 - 17.1 µmol/L',
      allowedUnits: ['mg/dL', 'umol/L', 'µmol/L'],
      aliases: ['Indirect Bilirubin', 'Unconjugated Bilirubin'],
      description: 'Bilirubin that has not yet been processed by the liver.',
    ),
    BiomarkerEntry(
      key: 'alp_u_l',
      standardName: 'ALP',
      unit: 'U/L',
      referenceRange: '44 - 147 U/L',
      referenceRangeSI: '0.73 - 2.45 µkat/L',
      allowedUnits: ['U/L', 'µkat/L'],
      aliases: ['Alkaline Phosphatase', 'Alk. Phosphatase'],
      description: 'An enzyme found in the liver, bones, kidneys, and digestive system.',
    ),
    BiomarkerEntry(
      key: 'alt_sgpt_u_l',
      standardName: 'ALT (SGPT)',
      unit: 'U/L',
      referenceRange: '7 - 56 U/L',
      referenceRangeSI: '0.12 - 0.93 µkat/L',
      allowedUnits: ['U/L', 'µkat/L'],
      aliases: ['ALT', 'SGPT', 'Alanine Aminotransferase', 'Alanine Transaminase'],
      description: 'An enzyme found mostly in the liver; high levels suggest liver damage.',
    ),
    BiomarkerEntry(
      key: 'ast_sgot_u_l',
      standardName: 'AST (SGOT)',
      unit: 'U/L',
      referenceRange: '8 - 48 U/L',
      referenceRangeSI: '0.13 - 0.80 µkat/L',
      allowedUnits: ['U/L', 'µkat/L'],
      aliases: ['AST', 'SGOT', 'Aspartate Aminotransferase', 'Aspartate Transaminase'],
      description: 'An enzyme found in the liver, heart, and muscles.',
    ),
    BiomarkerEntry(
      key: 'ggt_u_l',
      standardName: 'GGT',
      unit: 'U/L',
      referenceRange: '9 - 48 U/L',
      referenceRangeSI: '0.15 - 0.80 µkat/L',
      allowedUnits: ['U/L', 'µkat/L'],
      aliases: ['Gamma GT', 'Gamma Glutamyl Transferase', 'Gamma-Glutamyl Transpeptidase'],
      description: 'An enzyme found in the liver and bile ducts; sensitive to alcohol and bile duct issues.',
    ),
    BiomarkerEntry(
      key: 'protein_total_g_dl',
      standardName: 'Total Protein',
      unit: 'g/dL',
      referenceRange: '6.0 - 8.3 g/dL',
      referenceRangeSI: '60 - 83 g/L',
      allowedUnits: ['g/dL', 'g/L'],
      aliases: ['Protein Total', 'S. Protein', 'Serum Protein', 'Total Proteins'],
      description: 'The total amount of albumin and globulin in the blood.',
    ),
    BiomarkerEntry(
      key: 'albumin_g_dl',
      standardName: 'Albumin',
      unit: 'g/dL',
      referenceRange: '3.4 - 5.4 g/dL',
      referenceRangeSI: '34 - 54 g/L',
      allowedUnits: ['g/dL', 'g/L'],
      aliases: ['S. Albumin', 'Serum Albumin', 'Alb'],
      description: 'A protein made by the liver that keeps fluid from leaking out of blood vessels.',
    ),
    BiomarkerEntry(
      key: 'globulin_g_dl',
      standardName: 'Globulin',
      unit: 'g/dL',
      referenceRange: '2.0 - 3.5 g/dL',
      referenceRangeSI: '20 - 35 g/L',
      allowedUnits: ['g/dL', 'g/L'],
      aliases: ['S. Globulin', 'Serum Globulin'],
      description: 'A group of proteins in the blood that help the immune system and liver function.',
    ),
    BiomarkerEntry(
      key: 'a_g_ratio',
      standardName: 'A/G Ratio',
      unit: '',
      referenceRange: '1.1 - 2.5',
      referenceRangeSI: '1.1 - 2.5',
      aliases: ['Albumin/Globulin Ratio', 'AG Ratio'],
      description: 'The ratio of albumin to globulin in the blood.',
    ),

    // ─── Kidney Function ──────────────────────────────────
    BiomarkerEntry(
      key: 'creatinine_mg_dl',
      standardName: 'Creatinine',
      unit: 'mg/dL',
      referenceRange: '0.74 - 1.35 mg/dL Male | 0.59 - 1.04 mg/dL Female',
      referenceRangeSI: '65.4 - 119.3 µmol/L Male | 52.2 - 91.9 µmol/L Female',
      allowedUnits: ['mg/dL', 'umol/L', 'µmol/L'],
      aliases: ['S. Creatinine', 'Serum Creatinine', 'Creat'],
      description: 'A waste product from muscle breakdown, filtered by the kidneys.',
    ),
    BiomarkerEntry(
      key: 'urea_mg_dl',
      standardName: 'Urea',
      unit: 'mg/dL',
      referenceRange: '15 - 40 mg/dL',
      referenceRangeSI: '2.5 - 6.7 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Blood Urea', 'S. Urea', 'Serum Urea'],
      description: 'A waste product formed in the liver when protein is broken down.',
    ),
    BiomarkerEntry(
      key: 'bun_mg_dl',
      standardName: 'BUN',
      unit: 'mg/dL',
      referenceRange: '7 - 20 mg/dL',
      referenceRangeSI: '2.5 - 7.1 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Blood Urea Nitrogen'],
      description: 'The amount of nitrogen in your blood that comes from the waste product urea.',
    ),
    BiomarkerEntry(
      key: 'bun_creatinine_ratio',
      standardName: 'BUN/Creatinine Ratio',
      unit: '',
      referenceRange: '10:1 - 20:1',
      referenceRangeSI: '40:1 - 80:1 mmol/mmol',
      aliases: [],
      description: 'The ratio of BUN to creatinine, used to diagnose acute kidney issues.',
    ),
    BiomarkerEntry(
      key: 'sodium_mmol_l',
      standardName: 'Sodium',
      unit: 'mmol/L',
      referenceRange: '135 - 145 mmol/L',
      referenceRangeSI: '135 - 145 mmol/L',
      allowedUnits: ['mmol/L', 'mEq/L'],
      aliases: ['Na', 'Na+', 'S. Sodium', 'Serum Sodium'],
      description: 'An electrolyte that helps maintain fluid balance and nerve function.',
    ),
    BiomarkerEntry(
      key: 'potassium_mmol_l',
      standardName: 'Potassium',
      unit: 'mmol/L',
      referenceRange: '3.5 - 5.0 mmol/L',
      referenceRangeSI: '3.5 - 5.0 mmol/L',
      allowedUnits: ['mmol/L', 'mEq/L'],
      aliases: ['K', 'K+', 'S. Potassium', 'Serum Potassium'],
      description: 'An electrolyte vital for heart and muscle function.',
    ),
    BiomarkerEntry(
      key: 'chloride_mmol_l',
      standardName: 'Chloride',
      unit: 'mmol/L',
      referenceRange: '96 - 106 mmol/L',
      referenceRangeSI: '96 - 106 mmol/L',
      allowedUnits: ['mmol/L', 'mEq/L'],
      aliases: ['Cl', 'Cl-', 'S. Chloride', 'Serum Chloride'],
      description: 'An electrolyte that helps maintain proper blood volume and pressure.',
    ),
    BiomarkerEntry(
      key: 'uric_acid_mg_dl',
      standardName: 'Uric Acid',
      unit: 'mg/dL',
      referenceRange: '3.4 - 7.0 mg/dL Male | 2.4 - 6.0 mg/dL Female',
      referenceRangeSI: '202 - 416 µmol/L Male | 143 - 357 µmol/L Female',
      allowedUnits: ['mg/dL', 'µmol/L'],
      aliases: ['S. Uric Acid', 'Serum Uric Acid'],
      description: 'A waste product from the breakdown of purines; high levels can cause gout.',
    ),
    BiomarkerEntry(
      key: 'egfr_ml_min_173m2',
      standardName: 'eGFR',
      unit: 'mL/min/1.73m²',
      referenceRange: '> 90 mL/min/1.73m²',
      referenceRangeSI: '> 1.5 mL/s/1.73m²',
      allowedUnits: ['mL/min/1.73m²', 'mL/s/1.73m²'],
      aliases: ['Estimated GFR', 'Glomerular Filtration Rate'],
      description: 'A calculation of how well the kidneys are filtering waste from the blood.',
    ),

    // ─── Iron Profile ─────────────────────────────────────
    BiomarkerEntry(
      key: 'iron_ug_dl',
      standardName: 'Iron',
      unit: 'ug/dL',
      referenceRange: '65 - 176 µg/dL Male | 50 - 170 µg/dL Female',
      referenceRangeSI: '11.6 - 31.5 µmol/L Male | 9.0 - 30.4 µmol/L Female',
      allowedUnits: ['ug/dL', 'umol/L', 'µmol/L'],
      aliases: ['S. Iron', 'Serum Iron', 'Fe'],
      description: 'A mineral used by the body to make hemoglobin.',
    ),
    BiomarkerEntry(
      key: 'uibc_ug_dl',
      standardName: 'UIBC',
      unit: 'ug/dL',
      referenceRange: '112 - 346 µg/dL',
      referenceRangeSI: '20.0 - 61.9 µmol/L',
      allowedUnits: ['ug/dL', 'umol/L', 'µmol/L'],
      aliases: ['Unsaturated Iron Binding Capacity'],
      description: 'The reserve capacity of transferrin to bind iron.',
    ),
    BiomarkerEntry(
      key: 'tibc_ug_dl',
      standardName: 'TIBC',
      unit: 'ug/dL',
      referenceRange: '240 - 450 µg/dL',
      referenceRangeSI: '42.9 - 80.6 µmol/L',
      allowedUnits: ['ug/dL', 'umol/L', 'µmol/L'],
      aliases: ['Total Iron Binding Capacity'],
      description: 'The total capacity of the blood to carry iron.',
    ),
    BiomarkerEntry(
      key: 'transferrin_saturation_pct',
      standardName: 'Transferrin Saturation',
      unit: '%',
      referenceRange: '20% - 50%',
      referenceRangeSI: '0.20 - 0.50 fraction',
      allowedUnits: ['%'],
      aliases: ['TSAT', 'Iron Saturation'],
      description: 'The percentage of transferrin that is saturated with iron.',
    ),

    // ─── HbA1c ────────────────────────────────────────────
    BiomarkerEntry(
      key: 'hba1c_pct',
      standardName: 'HbA1c',
      unit: '%',
      referenceRange: '< 5.7%',
      referenceRangeSI: '< 39 mmol/mol',
      allowedUnits: ['%', 'mmol/mol'],
      aliases: ['Glycated Hemoglobin', 'Glycosylated Hemoglobin', 'A1C', 'Glycated Haemoglobin'],
      description: 'Measures average blood sugar levels over the past 2-3 months.',
    ),
    BiomarkerEntry(
      key: 'estimated_avg_glucose_mg_dl',
      standardName: 'Estimated Avg. Glucose',
      unit: 'mg/dL',
      referenceRange: '< 117 mg/dL',
      referenceRangeSI: '< 6.5 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['eAG', 'Estimated Average Glucose'],
      description: 'A calculated average of blood glucose based on HbA1c results.',
    ),
    BiomarkerEntry(
      key: 'hbf_pct',
      standardName: 'HbF',
      unit: '%',
      referenceRange: '< 2.0%',
      referenceRangeSI: '< 0.02 fraction',
      allowedUnits: ['%'],
      aliases: ['Fetal Hemoglobin'],
      description: 'A form of hemoglobin that is normal in infants but low in adults.',
    ),

    // ─── Urine ACR ────────────────────────────────────────
    BiomarkerEntry(
      key: 'urine_albumin_mg_l',
      standardName: 'Urine Albumin',
      unit: 'mg/L',
      referenceRange: '< 30 mg/L',
      referenceRangeSI: '< 30 mg/L',
      allowedUnits: ['mg/L'],
      aliases: ['Microalbumin', 'U. Albumin'],
      description: 'Small amounts of albumin in the urine, an early sign of kidney disease.',
    ),
    BiomarkerEntry(
      key: 'urine_creatinine_mg_dl',
      standardName: 'Urine Creatinine',
      unit: 'mg/dL',
      referenceRange: '20 - 275 mg/dL Male | 15 - 225 mg/dL Female',
      referenceRangeSI: '1.77 - 24.3 mmol/L Male | 1.33 - 19.9 mmol/L Female',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['U. Creatinine'],
      description: 'Creatinine measured in a urine sample.',
    ),
    BiomarkerEntry(
      key: 'albumin_creatinine_ratio',
      standardName: 'Albumin/Creatinine Ratio',
      unit: '',
      referenceRange: '< 30 mg/g',
      referenceRangeSI: '< 3.4 mg/mmol',
      allowedUnits: ['mg/g', 'mg/mmol'],
      aliases: ['ACR', 'Urine ACR'],
      description: 'The ratio of albumin to creatinine in the urine, used to detect kidney damage.',
    ),

    // ─── Calcium & Phosphorus ─────────────────────────────
    BiomarkerEntry(
      key: 'calcium_mg_dl',
      standardName: 'Calcium',
      unit: 'mg/dL',
      referenceRange: '8.5 - 10.2 mg/dL',
      referenceRangeSI: '2.12 - 2.55 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Ca', 'Ca++', 'S. Calcium', 'Serum Calcium', 'Total Calcium'],
      description: 'Important for bone health, muscle function, and nerve signaling.',
    ),
    BiomarkerEntry(
      key: 'phosphorus_mg_dl',
      standardName: 'Phosphorus',
      unit: 'mg/dL',
      referenceRange: '2.5 - 4.5 mg/dL',
      referenceRangeSI: '0.81 - 1.45 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Phosphate', 'Phos', 'S. Phosphorus', 'Inorganic Phosphorus'],
      description: 'A mineral that works with calcium to build bones and teeth.',
    ),

    // ─── Thyroid Profile ──────────────────────────────────
    BiomarkerEntry(
      key: 'tt3_ng_dl',
      standardName: 'Total T3',
      unit: 'ng/dL',
      referenceRange: '80 - 200 ng/dL',
      referenceRangeSI: '1.2 - 3.1 nmol/L',
      allowedUnits: ['ng/dL', 'nmol/L'],
      aliases: ['T3', 'TT3', 'Triiodothyronine'],
      description: 'One of the two main hormones produced by the thyroid gland.',
    ),
    BiomarkerEntry(
      key: 'tt4_ug_dl',
      standardName: 'Total T4',
      unit: 'ug/dL',
      referenceRange: '5.0 - 12.0 µg/dL',
      referenceRangeSI: '64 - 154 nmol/L',
      allowedUnits: ['ug/dL', 'nmol/L'],
      aliases: ['T4', 'TT4', 'Thyroxine'],
      description: 'The main hormone produced by the thyroid gland.',
    ),
    BiomarkerEntry(
      key: 'tsh_uiu_ml',
      standardName: 'TSH',
      unit: 'uIU/mL',
      referenceRange: '0.4 - 4.0 µIU/mL',
      referenceRangeSI: '0.4 - 4.0 mIU/L',
      allowedUnits: ['uIU/mL', 'mIU/L'],
      aliases: ['Thyroid Stimulating Hormone', 'Thyrotropin'],
      description: 'Hormone from the pituitary gland that tells the thyroid to make T3 and T4.',
    ),

    // ─── Glucose ──────────────────────────────────────────
    BiomarkerEntry(
      key: 'fasting_glucose_mg_dl',
      standardName: 'Fasting Glucose',
      unit: 'mg/dL',
      referenceRange: '70 - 99 mg/dL',
      referenceRangeSI: '3.9 - 5.5 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['FBS', 'Fasting Blood Sugar', 'Fasting Blood Glucose', 'Glucose Fasting', 'F. Glucose'],
      description: 'Blood sugar level measured after an 8-12 hour fast.',
    ),
    BiomarkerEntry(
      key: 'postprandial_glucose_mg_dl',
      standardName: 'Postprandial Glucose',
      unit: 'mg/dL',
      referenceRange: '< 140 mg/dL',
      referenceRangeSI: '< 7.8 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['PPBS', 'PP Blood Sugar', 'PP Glucose', 'Post Prandial Blood Sugar', 'Glucose PP'],
      description: 'Blood sugar level measured 2 hours after a meal.',
    ),
    BiomarkerEntry(
      key: 'fbs_mg_dl',
      standardName: 'FBS',
      unit: 'mg/dL',
      referenceRange: '70 - 99 mg/dL',
      referenceRangeSI: '3.9 - 5.5 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Fasting Blood Sugar'],
      description: 'Fasting Blood Sugar (Diagnostic specific).',
    ),
    BiomarkerEntry(
      key: 'plbs_mg_dl',
      standardName: 'PLBS',
      unit: 'mg/dL',
      referenceRange: '< 140 mg/dL',
      referenceRangeSI: '< 7.8 mmol/L',
      allowedUnits: ['mg/dL', 'mmol/L'],
      aliases: ['Post Lunch Blood Sugar'],
      description: 'Post Lunch Blood Sugar (Diagnostic specific).',
    ),
  ];

  /// Normalize a string for comparison: lowercase, remove special chars.
  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static BiomarkerEntry? getEntryByKey(String key) {
    for (var entry in entries) {
      if (entry.key == key) {
        return entry;
      }
    }
    return null;
  }

  /// Find the best matching BiomarkerEntry for a given test item name.
  /// Returns null if no confident match is found.
  static BiomarkerEntry? match(String testItem, {String? unit}) {
    if (testItem.isEmpty) return null;
    final input = testItem.trim();
    final inputNorm = _normalize(input);
    if (inputNorm.isEmpty) return null;

    // Helper to normalize unit string for safe, lenient comparison
    String? cleanUnit(String? u) {
      if (u == null) return null;
      return u.toLowerCase().trim()
          .replaceAll(' ', '')
          .replaceAll('^', '')
          .replaceAll('10*', '10')
          .replaceAll('10e', '10')
          .replaceAll('×10', '10')
          .replaceAll('x10', '10');
    }

    final targetUnit = cleanUnit(unit);

    // Helper to get enhanced aliases dynamically to support a wider range of diagnostic lab variations
    List<String> getDynamicAliases(BiomarkerEntry e) {
      final list = List<String>.from(e.aliases);
      if (e.key == 'wbc_cells_ul') {
        list.addAll(['White Cell Count', 'Total WBC Count', 'WBC Count', 'Leukocytes', 'wbc']);
      } else if (e.key == 'rbc_count_mil_ul') {
        list.addAll(['Red Blood Cell', 'Red Cell Count', 'Total RBC Count', 'rbc']);
      } else if (e.key == 'platelet_count_x10_3_ul') {
        list.addAll(['Platelet', 'Total Platelet Count', 'PLT Count', 'plt']);
      } else if (e.key == 'hemoglobin_g_dl') {
        list.addAll(['Hb', 'Hgb', 'Hemoglobin (Hb)', 'hb']);
      } else if (e.key == 'neutrophils_pct') {
        list.addAll(['Polymorphs', 'Neutrophils (Polymorphs)', 'neut']);
      } else if (e.key == 'egfr_ml_min_173m2') {
        list.addAll(['e-GFR', 'eGFR (non-African American)', 'egfr']);
      }
      return list;
    }

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
      final aliases = getDynamicAliases(e);
      for (final alias in aliases) {
        if (alias.toLowerCase() == input.toLowerCase()) return e;
      }
    }

    // Helper to get normalized words from a string
    List<String> getWords(String s) {
      return s.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
    }

    final inputWords = getWords(input);
    if (inputWords.isEmpty) return null;

    BiomarkerEntry? bestMatch;
    double bestScore = 0.0;

    for (final e in entries) {
      final aliases = getDynamicAliases(e);
      final targets = [e.standardName, ...aliases];
      
      for (final target in targets) {
        final targetWords = getWords(target);
        if (targetWords.isEmpty) continue;

        // Calculate intersection
        int intersection = 0;
        final tempTargetWords = List<String>.from(targetWords);
        for (final iw in inputWords) {
          final idx = tempTargetWords.indexOf(iw);
          if (idx != -1) {
            intersection++;
            tempTargetWords.removeAt(idx);
          }
        }

        if (intersection == 0) continue;

        // Calculate overlap coefficient (intersection / min(inputWords.length, targetWords.length))
        final double overlap = intersection / (inputWords.length < targetWords.length ? inputWords.length : targetWords.length);
        
        // Calculate Jaccard similarity (intersection / union)
        final int union = inputWords.length + targetWords.length - intersection;
        final double jaccard = intersection / union;

        // Combine into a composite score
        double score = (jaccard * 0.6) + (overlap * 0.4);

        // Boost score if the first word matches exactly
        if (inputWords.first == targetWords.first) {
          score += 0.1;
        }

        // Penalty for matching extremely short common words like "abs" alone
        if (inputWords.length == 1 && inputWords.first.length <= 3) {
          score *= 0.2; // Severely penalize single short word matches
        }

        // Unit-based boost / penalty for disambiguation!
        if (targetUnit != null && targetUnit.isNotEmpty) {
          bool allowsUnit = false;
          for (final allowed in e.allowedUnits) {
            if (cleanUnit(allowed) == targetUnit) {
              allowsUnit = true;
              break;
            }
          }
          if (allowsUnit) {
            // Strong boost if the unit is supported
            score += 0.35;
          } else if (e.allowedUnits.isNotEmpty) {
            // Penalty if the entry has allowed units but none match the extracted unit
            score -= 0.25;
          }
        }

        if (score > bestScore) {
          bestScore = score;
          bestMatch = e;
        }
      }
    }

    // Return the match only if it meets our confidence threshold of 0.45
    // (Reduced slightly from 0.5 to account for longer user inputs, but compensated by unit boosts)
    return bestScore >= 0.45 ? bestMatch : null;
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

  /// Parses a combined reference range string (e.g. "Male: 13.8-17.2 | Female: 12.1-15.1") 
  /// and returns only the range matching the given gender.
  static String? getGenderSpecificRange(String? referenceRange, String? gender) {
    if (referenceRange == null || referenceRange.isEmpty) return referenceRange;
    if (gender == null || gender.trim().isEmpty) return referenceRange;

    final cleanGender = gender.trim().toLowerCase();
    final isMale = cleanGender.startsWith('m') && !cleanGender.startsWith('f');
    final isFemale = cleanGender.startsWith('f');

    if (!isMale && !isFemale) return referenceRange;

    final parts = referenceRange.split('|');
    if (parts.length < 2) return referenceRange;

    for (var part in parts) {
      final trimmedPart = part.trim();
      final lowerPart = trimmedPart.toLowerCase();
      final partIsFemale = lowerPart.contains('female');
      final partIsMale = lowerPart.contains('male') && !partIsFemale;

      if (isFemale && partIsFemale) {
        return _cleanGenderLabels(trimmedPart, 'female');
      }
      if (isMale && partIsMale) {
        return _cleanGenderLabels(trimmedPart, 'male');
      }
    }

    return referenceRange;
  }

  static String _cleanGenderLabels(String part, String genderWord) {
    final regExpPrefix = RegExp('^$genderWord\\s*:\\s*', caseSensitive: false);
    final regExpSuffix = RegExp('\\s+$genderWord\\s*\$', caseSensitive: false);
    var cleaned = part.replaceAll(regExpPrefix, '').replaceAll(regExpSuffix, '');
    return cleaned.trim();
  }
}
