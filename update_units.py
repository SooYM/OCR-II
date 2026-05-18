import re

with open('backend/unit_converter.py', 'r') as f:
    py_content = f.read()

new_conversions = """
    # 8. Calcium
    elif key == 'calcium_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 4.0
            
    # 9. Phosphorus
    elif key == 'phosphorus_mg_dl':
        if ext_unit == 'mmol/l' and std_unit == 'mg/dl':
            return number * 3.097
            
    # 10. Iron / UIBC / TIBC
    elif key in ['iron_ug_dl', 'uibc_ug_dl', 'tibc_ug_dl']:
        if ext_unit in ['umol/l', 'µmol/l'] and std_unit == 'ug/dl':
            return number * 5.59
            
    # 11. Proteins
    elif key in ['protein_total_g_dl', 'albumin_g_dl', 'globulin_g_dl']:
        if ext_unit == 'g/l' and std_unit == 'g/dl':
            return number / 10.0
            
    # 12. T3 Total
    elif key == 'tt3_ng_dl':
        if ext_unit == 'nmol/l' and std_unit == 'ng/dl':
            return number / 0.01536
            
    # 13. T4 Total
    elif key == 'tt4_ug_dl':
        if ext_unit == 'nmol/l' and std_unit == 'ug/dl':
            return number / 12.87
"""

py_content = py_content.replace('    return number\n', new_conversions + '\n    return number\n')

with open('backend/unit_converter.py', 'w') as f:
    f.write(py_content)


with open('frontend/lib/utils/biomarker_dictionary.dart', 'r') as f:
    dart_content = f.read()

dart_content = dart_content.replace(
    "key: 'calcium_mg_dl', standardName: 'Calcium', unit: 'mg/dL', referenceRange: '8.5 - 10.5', allowedUnits: ['mg/dL']",
    "key: 'calcium_mg_dl', standardName: 'Calcium', unit: 'mg/dL', referenceRange: '8.5 - 10.5', allowedUnits: ['mg/dL', 'mmol/L']"
).replace(
    "key: 'phosphorus_mg_dl', standardName: 'Phosphorus', unit: 'mg/dL', referenceRange: '2.5 - 4.5', allowedUnits: ['mg/dL']",
    "key: 'phosphorus_mg_dl', standardName: 'Phosphorus', unit: 'mg/dL', referenceRange: '2.5 - 4.5', allowedUnits: ['mg/dL', 'mmol/L']"
).replace(
    "key: 'iron_ug_dl', standardName: 'Iron', unit: 'ug/dL', referenceRange: '60 - 170', allowedUnits: ['ug/dL']",
    "key: 'iron_ug_dl', standardName: 'Iron', unit: 'ug/dL', referenceRange: '60 - 170', allowedUnits: ['ug/dL', 'umol/L']"
).replace(
    "key: 'uibc_ug_dl', standardName: 'UIBC', unit: 'ug/dL', allowedUnits: ['ug/dL']",
    "key: 'uibc_ug_dl', standardName: 'UIBC', unit: 'ug/dL', allowedUnits: ['ug/dL', 'umol/L']"
).replace(
    "key: 'tibc_ug_dl', standardName: 'TIBC', unit: 'ug/dL', referenceRange: '250 - 370', allowedUnits: ['ug/dL']",
    "key: 'tibc_ug_dl', standardName: 'TIBC', unit: 'ug/dL', referenceRange: '250 - 370', allowedUnits: ['ug/dL', 'umol/L']"
).replace(
    "key: 'protein_total_g_dl', standardName: 'Total Protein', unit: 'g/dL', referenceRange: '6.0 - 8.3', allowedUnits: ['g/dL']",
    "key: 'protein_total_g_dl', standardName: 'Total Protein', unit: 'g/dL', referenceRange: '6.0 - 8.3', allowedUnits: ['g/dL', 'g/L']"
).replace(
    "key: 'albumin_g_dl', standardName: 'Albumin', unit: 'g/dL', referenceRange: '3.5 - 5.5', allowedUnits: ['g/dL']",
    "key: 'albumin_g_dl', standardName: 'Albumin', unit: 'g/dL', referenceRange: '3.5 - 5.5', allowedUnits: ['g/dL', 'g/L']"
).replace(
    "key: 'globulin_g_dl', standardName: 'Globulin', unit: 'g/dL', referenceRange: '2.0 - 3.5', allowedUnits: ['g/dL']",
    "key: 'globulin_g_dl', standardName: 'Globulin', unit: 'g/dL', referenceRange: '2.0 - 3.5', allowedUnits: ['g/dL', 'g/L']"
).replace(
    "key: 'tt3_ng_dl', standardName: 'Total T3', unit: 'ng/dL', referenceRange: '80 - 200', allowedUnits: ['ng/dL']",
    "key: 'tt3_ng_dl', standardName: 'Total T3', unit: 'ng/dL', referenceRange: '80 - 200', allowedUnits: ['ng/dL', 'nmol/L']"
).replace(
    "key: 'tt4_ug_dl', standardName: 'Total T4', unit: 'ug/dL', referenceRange: '5.1 - 14.1', allowedUnits: ['ug/dL']",
    "key: 'tt4_ug_dl', standardName: 'Total T4', unit: 'ug/dL', referenceRange: '5.1 - 14.1', allowedUnits: ['ug/dL', 'nmol/L']"
)

with open('frontend/lib/utils/biomarker_dictionary.dart', 'w') as f:
    f.write(dart_content)
