import 'frontend/lib/utils/unit_converter.dart';
import 'frontend/lib/utils/biomarker_dictionary.dart';

void main() {
  print(UnitConverter.convertRange('total_cholesterol_mg_dl', '8.5 - 10.5', 'mg/dL', 'mmol/L'));
  print(UnitConverter.convertRange('postprandial_glucose_mg_dl', '< 140', 'mg/dL', 'mmol/L'));
}
