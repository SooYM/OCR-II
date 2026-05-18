import 'frontend/lib/utils/unit_converter.dart';

void main() {
  print('Glucose: ' + UnitConverter.convertRange('fasting_glucose_mg_dl', '70 - 100', 'mg/dL', 'mmol/L'));
  print('Calcium: ' + UnitConverter.convertRange('calcium_mg_dl', '8.5 - 10.5', 'mg/dL', 'mmol/L'));
  print('Creatinine: ' + UnitConverter.convertRange('creatinine_mg_dl', '0.7 - 1.2', 'mg/dL', 'umol/L'));
}
