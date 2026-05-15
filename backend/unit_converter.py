import re

def convert_unit(key: str, raw_value: str, extracted_unit: str, standard_unit: str) -> float:
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

    # 1. Cholesterol
    if key in ['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl']:
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 38.67
            
    # 2. Triglycerides
    elif key == 'triglycerides_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 88.57
            
    # 3. Glucose
    elif key in ['fasting_glucose_mg_dl', 'random_glucose_mg_dl', 'pp_glucose_mg_dl', 'fbs_mg_dl', 'plbs_mg_dl']:
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 18.018
            
    # 4. Creatinine
    elif key == 'creatinine_mg_dl':
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit == 'mg/dl':
            return number / 88.42
            
    # 5. Bilirubin
    elif key in ['bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl']:
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit == 'mg/dl':
            return number / 17.1
            
    # 6. Uric Acid
    elif key == 'uric_acid_mg_dl':
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit == 'mg/dl':
            return number / 59.48
            
    # 7. Urea
    elif key == 'urea_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 6.006

    return number
