import re

with open('frontend/lib/utils/biomarker_dictionary.dart', 'r') as f:
    content = f.read()

# Update the class definition
content = re.sub(
    r'(final String unit;\n\s+final String\? referenceRange;\n\s+final List<String> aliases;\n)',
    r'\1  final List<String> allowedUnits;\n',
    content
)

content = re.sub(
    r'(this\.aliases = const \[\],)\n(\s+this\.description)',
    r'\1\n    this.allowedUnits = const [],\n\2',
    content
)

# Function to add allowedUnits based on the standard unit
def inject_allowed(match):
    full = match.group(0)
    # Find the unit value
    unit_match = re.search(r"unit: '([^']+)'", full)
    key_match = re.search(r"key: '([^']+)'", full)
    if not unit_match or not key_match:
        return full
    
    std_unit = unit_match.group(1)
    key = key_match.group(1)
    
    allowed = set()
    if std_unit:
        allowed.add(std_unit)
        
    # Add common conversions based on key
    if key in ['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl', 'triglycerides_mg_dl', 'fasting_glucose_mg_dl', 'postprandial_glucose_mg_dl', 'fbs_mg_dl', 'plbs_mg_dl', 'urea_mg_dl']:
        allowed.add('mg/dL')
        allowed.add('mmol/L')
    elif key in ['creatinine_mg_dl', 'bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl', 'uric_acid_mg_dl']:
        allowed.add('mg/dL')
        allowed.add('umol/L')
        allowed.add('µmol/L')
    
    # Just list them out
    if len(allowed) > 0:
        allowed_str = "[" + ", ".join([f"'{u}'" for u in sorted(allowed)]) + "]"
        full = full.replace("aliases: [", f"allowedUnits: {allowed_str}, aliases: [")
    else:
        full = full.replace("aliases: [", f"allowedUnits: [], aliases: [")
        
    return full

content = re.sub(r'BiomarkerEntry\([^)]+\)', inject_allowed, content)

with open('frontend/lib/utils/biomarker_dictionary.dart', 'w') as f:
    f.write(content)
