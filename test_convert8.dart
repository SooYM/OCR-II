import 'frontend/lib/utils/unit_converter.dart';
import 'frontend/lib/models/report_model.dart';
import 'frontend/lib/utils/biomarker_dictionary.dart';

void main() {
  TestResult result = TestResult(testItem: 'Calcium', value: '8.5', unit: 'mg/dL', referenceRange: '8.5 - 10.5', key: 'calcium_mg_dl');
  String v = 'mmol/L';
  
  final matchEntry = BiomarkerDictionary.getEntryByKey(result.key!);
  
  if (result.unit != null && result.unit!.isNotEmpty && result.unit != v) {
    if (result.referenceRange != null && result.referenceRange!.isNotEmpty) {
      final newRange = UnitConverter.convertRange(matchEntry!.key, result.referenceRange!, result.unit!, v);
      result.referenceRange = newRange;
    }
  }
  result.unit = v;
  
  print('New Reference Range: ' + result.referenceRange!);
}
