import re

def convert_unit(key: str, raw_value: str, extracted_unit: str, standard_unit: str) -> float:
    """
    Converts an OCR-extracted value from extracted_unit → standard_unit.
    Used during OCR processing to normalize SI units back to the standard storage unit.
    Returns the numeric value (converted if applicable), or None if not parseable.
    """
    if not raw_value:
        return None
        
    ext_unit = str(extracted_unit).lower().replace(' ', '') if extracted_unit else ""
    std_unit = str(standard_unit).lower().replace(' ', '') if standard_unit else ""
    
    # Extract numeric portion (e.g. "< 3.8" -> 3.8)
    match = re.search(r'([0-9]*\.?[0-9]+)', str(raw_value).strip())
    if not match:
        return None
        
    number = float(match.group(1))
    
    if ext_unit == std_unit or not ext_unit:
        return number

    # ─── LIPID PROFILE ───────────────────────────────────
    # Cholesterol: 1 mmol/L = 38.67 mg/dL
    if key in ['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl', 'non_hdl_mg_dl']:
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 38.67
            
    # Triglycerides: 1 mmol/L = 88.57 mg/dL
    elif key == 'triglycerides_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 88.57
            
    # ─── GLUCOSE ─────────────────────────────────────────
    elif key in ['fasting_glucose_mg_dl', 'random_glucose_mg_dl', 'postprandial_glucose_mg_dl', 
                 'fbs_mg_dl', 'plbs_mg_dl', 'estimated_avg_glucose_mg_dl']:
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 18.018
            
    # ─── KIDNEY FUNCTION ─────────────────────────────────
    # Creatinine: 1 µmol/L = 1/88.42 mg/dL
    elif key == 'creatinine_mg_dl':
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit == 'mg/dl':
            return number / 88.42
            
    # Urea: 1 mmol/L = 6.006 mg/dL
    elif key == 'urea_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 6.006

    # BUN: 1 mmol/L = 2.8 mg/dL
    elif key == 'bun_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 2.8

    # Uric Acid: 1 µmol/L = 1/59.48 mg/dL
    elif key == 'uric_acid_mg_dl':
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit == 'mg/dl':
            return number / 59.48

    # Sodium/Potassium/Chloride: mmol/L = mEq/L (1:1)
    elif key in ['sodium_mmol_l', 'potassium_mmol_l', 'chloride_mmol_l']:
        if ext_unit == 'meq/l' and std_unit == 'mmol/l':
            return number  # 1:1

    # eGFR: 1 mL/s/1.73m² = 60 mL/min/1.73m²
    elif key == 'egfr_ml_min_173m2':
        if ext_unit in ['ml/s/1.73m²', 'ml/s/1.73m2'] and std_unit in ['ml/min/1.73m²', 'ml/min/1.73m2']:
            return number * 60.0

    # Urine Creatinine: 1 mmol/L = 11.312 mg/dL
    elif key == 'urine_creatinine_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 11.312

    # ─── LIVER FUNCTION ──────────────────────────────────
    # Bilirubin: 1 µmol/L = 1/17.1 mg/dL
    elif key in ['bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl']:
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit == 'mg/dl':
            return number / 17.1

    # Enzymes: 1 µkat/L = 60 U/L
    elif key in ['alp_u_l', 'alt_sgpt_u_l', 'ast_sgot_u_l', 'ggt_u_l']:
        if ext_unit in ['µkat/l', 'ukat/l'] and std_unit == 'u/l':
            return number * 60.0

    # Proteins: 1 g/L = 0.1 g/dL
    elif key in ['protein_total_g_dl', 'albumin_g_dl', 'globulin_g_dl']:
        if ext_unit == 'g/l' and std_unit == 'g/dl':
            return number / 10.0

    # ─── CBC ─────────────────────────────────────────────
    # Hemoglobin / MCHC: 1 g/L = 0.1 g/dL
    elif key in ['hemoglobin_g_dl', 'mchc_g_dl']:
        if ext_unit == 'g/l' and std_unit == 'g/dl':
            return number / 10.0

    # RBC Count: 10^12/L = mil/µL (1:1)
    elif key == 'rbc_count_mil_ul':
        if ext_unit == '10^12/l' and std_unit in ['mil/ul', 'mil/µl']:
            return number  # 1:1

    # WBC: 1 × 10^9/L = 1000 cells/µL
    elif key == 'wbc_cells_ul':
        if ext_unit == '10^9/l' and std_unit in ['cells/ul', 'cells/µl']:
            return number * 1000.0

    # Absolute counts: 10^9/L → cells/µL
    elif key in ['abs_neutrophils', 'abs_lymphocytes', 'abs_monocytes', 'abs_eosinophils', 'abs_basophils']:
        if ext_unit == '10^9/l' and std_unit in ['cells/ul', 'cells/µl']:
            return number * 1000.0

    # Platelet Count: 10^9/L = x10³/µL (1:1)
    elif key == 'platelet_count_x10_3_ul':
        if ext_unit == '10^9/l' and std_unit in ['x10³/ul', 'x10^3/ul']:
            return number  # 1:1

    # ─── IRON PROFILE ────────────────────────────────────
    elif key in ['iron_ug_dl', 'uibc_ug_dl', 'tibc_ug_dl']:
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit in ['ug/dl', 'µg/dl']:
            return number * 5.59

    # ─── CALCIUM & PHOSPHORUS ────────────────────────────
    elif key == 'calcium_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 4.0
            
    elif key == 'phosphorus_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 3.097

    # ─── THYROID ─────────────────────────────────────────
    # T3: 1 nmol/L = 1/0.01536 ng/dL
    elif key == 'tt3_ng_dl':
        if ext_unit == 'nmol/l' and std_unit == 'ng/dl':
            return number / 0.01536
            
    # T4: 1 nmol/L = 1/12.87 µg/dL
    elif key == 'tt4_ug_dl':
        if ext_unit == 'nmol/l' and std_unit in ['ug/dl', 'µg/dl']:
            return number / 12.87

    # TSH: mIU/L = µIU/mL (1:1)
    elif key == 'tsh_uiu_ml':
        if ext_unit in ['miu/l'] and std_unit in ['uiu/ml', 'µiu/ml']:
            return number  # 1:1

    # ─── HbA1c (Non-linear) ──────────────────────────────
    # mmol/mol → %: % = 0.09148 × mmol/mol + 2.152
    elif key == 'hba1c_pct':
        if ext_unit == 'mmol/mol' and std_unit == '%':
            return (number * 0.09148) + 2.152

    return number
