import 'frontend/lib/utils/unit_converter.dart';

void main() {
  final res = UnitConverter.convertRange('postprandial_glucose_mg_dl', '< 140', 'mg/dL', 'mmol/L');
  print('Result: $res');
}
