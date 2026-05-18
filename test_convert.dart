import 'frontend/lib/utils/unit_converter.dart';

void main() {
  final res = UnitConverter.convertRange('total_cholesterol_mg_dl', '8.5 - 10.5', 'mg/dL', 'mmol/L');
  print('Result: $res');
}
