import 'frontend/lib/utils/unit_converter.dart';

void main() {
  print('Calcium: ' + UnitConverter.convertRange('calcium_mg_dl', '8.5-10.5', 'mg/dL', 'mmol/L'));
}
