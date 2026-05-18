import 'package:flutter_test/flutter_test.dart';
import 'package:medscan_app/utils/unit_converter.dart';

void main() {
  group('UnitConverter - Lipid Profile', () {
    test('Total Cholesterol mg/dL → mmol/L', () {
      final r = UnitConverter.convert('total_cholesterol_mg_dl', '200', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(5.17, 0.1));
    });
    test('Total Cholesterol mmol/L → mg/dL', () {
      final r = UnitConverter.convert('total_cholesterol_mg_dl', '5.17', 'mmol/L', 'mg/dL');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(200, 1));
    });
    test('HDL mg/dL → mmol/L', () {
      final r = UnitConverter.convert('hdl_mg_dl', '50', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(1.29, 0.1));
    });
    test('Non-HDL mg/dL → mmol/L', () {
      final r = UnitConverter.convert('non_hdl_mg_dl', '130', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(3.36, 0.1));
    });
    test('Triglycerides mg/dL → mmol/L', () {
      final r = UnitConverter.convert('triglycerides_mg_dl', '150', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(1.69, 0.1));
    });
  });

  group('UnitConverter - Glucose', () {
    test('Fasting Glucose mg/dL → mmol/L', () {
      final r = UnitConverter.convert('fasting_glucose_mg_dl', '100', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(5.55, 0.1));
    });
    test('Fasting Glucose mmol/L → mg/dL', () {
      final r = UnitConverter.convert('fasting_glucose_mg_dl', '5.55', 'mmol/L', 'mg/dL');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(100, 1));
    });
    test('Estimated Avg Glucose mg/dL → mmol/L', () {
      final r = UnitConverter.convert('estimated_avg_glucose_mg_dl', '117', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(6.49, 0.1));
    });
  });

  group('UnitConverter - Kidney Function', () {
    test('Creatinine mg/dL → µmol/L', () {
      final r = UnitConverter.convert('creatinine_mg_dl', '1.0', 'mg/dL', 'µmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(88.42, 1));
    });
    test('Creatinine µmol/L → mg/dL', () {
      final r = UnitConverter.convert('creatinine_mg_dl', '88.42', 'µmol/L', 'mg/dL');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(1.0, 0.05));
    });
    test('Urea mg/dL → mmol/L', () {
      final r = UnitConverter.convert('urea_mg_dl', '30', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(5.0, 0.1));
    });
    test('BUN mg/dL → mmol/L', () {
      final r = UnitConverter.convert('bun_mg_dl', '14', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(5.0, 0.1));
    });
    test('Uric Acid mg/dL → µmol/L', () {
      final r = UnitConverter.convert('uric_acid_mg_dl', '7.0', 'mg/dL', 'µmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(416, 5));
    });
    test('Sodium mmol/L → mEq/L (1:1)', () {
      final r = UnitConverter.convert('sodium_mmol_l', '140', 'mmol/L', 'mEq/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(140, 0.1));
    });
    test('Urine Creatinine mg/dL → mmol/L', () {
      final r = UnitConverter.convert('urine_creatinine_mg_dl', '100', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(8.84, 0.1));
    });
  });

  group('UnitConverter - Liver Function', () {
    test('Bilirubin Total mg/dL → µmol/L', () {
      final r = UnitConverter.convert('bilirubin_total_mg_dl', '1.0', 'mg/dL', 'µmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(17.1, 0.5));
    });
    test('ALT U/L → µkat/L', () {
      final r = UnitConverter.convert('alt_sgpt_u_l', '30', 'U/L', 'µkat/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(0.5, 0.05));
    });
    test('ALT µkat/L → U/L', () {
      final r = UnitConverter.convert('alt_sgpt_u_l', '0.5', 'µkat/L', 'U/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(30, 1));
    });
    test('Total Protein g/dL → g/L', () {
      final r = UnitConverter.convert('protein_total_g_dl', '7.0', 'g/dL', 'g/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(70, 1));
    });
  });

  group('UnitConverter - CBC', () {
    test('Hemoglobin g/dL → g/L', () {
      final r = UnitConverter.convert('hemoglobin_g_dl', '15.0', 'g/dL', 'g/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(150, 1));
    });
    test('WBC cells/uL → 10^9/L', () {
      final r = UnitConverter.convert('wbc_cells_ul', '7000', 'cells/uL', '10^9/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(7.0, 0.1));
    });
    test('WBC 10^9/L → cells/uL', () {
      final r = UnitConverter.convert('wbc_cells_ul', '7.0', '10^9/L', 'cells/uL');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(7000, 10));
    });
    test('RBC mil/uL → 10^12/L (1:1)', () {
      final r = UnitConverter.convert('rbc_count_mil_ul', '5.0', 'mil/uL', '10^12/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(5.0, 0.1));
    });
    test('Abs Neutrophils cells/uL → 10^9/L', () {
      final r = UnitConverter.convert('abs_neutrophils', '4000', 'cells/uL', '10^9/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(4.0, 0.1));
    });
    test('Platelet x10³/uL → 10^9/L (1:1)', () {
      final r = UnitConverter.convert('platelet_count_x10_3_ul', '250', 'x10³/uL', '10^9/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(250, 1));
    });
  });

  group('UnitConverter - Iron Profile', () {
    test('Iron µg/dL → µmol/L', () {
      final r = UnitConverter.convert('iron_ug_dl', '100', 'ug/dL', 'umol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(17.9, 0.5));
    });
  });

  group('UnitConverter - Thyroid', () {
    test('T3 ng/dL → nmol/L', () {
      final r = UnitConverter.convert('tt3_ng_dl', '100', 'ng/dL', 'nmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(1.54, 0.1));
    });
    test('T4 µg/dL → nmol/L', () {
      final r = UnitConverter.convert('tt4_ug_dl', '8.0', 'ug/dL', 'nmol/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(103, 5));
    });
    test('TSH µIU/mL → mIU/L (1:1)', () {
      final r = UnitConverter.convert('tsh_uiu_ml', '2.5', 'uIU/mL', 'mIU/L');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(2.5, 0.1));
    });
  });

  group('UnitConverter - HbA1c (non-linear)', () {
    test('HbA1c % → mmol/mol', () {
      final r = UnitConverter.convert('hba1c_pct', '5.7', '%', 'mmol/mol');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(39, 1));
    });
    test('HbA1c mmol/mol → %', () {
      final r = UnitConverter.convert('hba1c_pct', '39', 'mmol/mol', '%');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(5.7, 0.1));
    });
    test('HbA1c 6.5% → 48 mmol/mol', () {
      final r = UnitConverter.convert('hba1c_pct', '6.5', '%', 'mmol/mol');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(48, 1));
    });
  });

  group('UnitConverter - eGFR', () {
    test('eGFR mL/min → mL/s', () {
      final r = UnitConverter.convert('egfr_ml_min_173m2', '90', 'mL/min/1.73m²', 'mL/s/1.73m²');
      expect(r.wasConverted, true);
      expect(double.parse(r.convertedValue), closeTo(1.5, 0.1));
    });
  });

  group('UnitConverter - Reference Range Conversion', () {
    test('Hemoglobin range g/dL → g/L (X - Y format)', () {
      final r = UnitConverter.convertRange('hemoglobin_g_dl', '13.5 - 17.5', 'g/dL', 'g/L');
      final parts = r.split(' - ');
      expect(double.parse(parts[0]), closeTo(135, 1));
      expect(double.parse(parts[1]), closeTo(175, 1));
    });
    
    test('Cholesterol range mg/dL → mmol/L (< X format)', () {
      final r = UnitConverter.convertRange('total_cholesterol_mg_dl', '< 200', 'mg/dL', 'mmol/L');
      expect(r.startsWith('< '), true);
      expect(double.parse(r.replaceAll(RegExp(r'[^0-9.]'), '')), closeTo(5.17, 0.1));
    });
    
    test('HDL range mg/dL → mmol/L (> X format)', () {
      final r = UnitConverter.convertRange('hdl_mg_dl', '> 40', 'mg/dL', 'mmol/L');
      expect(r.startsWith('> '), true);
      expect(double.parse(r.replaceAll(RegExp(r'[^0-9.]'), '')), closeTo(1.03, 0.1));
    });
    
    test('WBC range cells/uL → 10^9/L (Large numbers)', () {
      final r = UnitConverter.convertRange('wbc_cells_ul', '4000 - 11000', 'cells/uL', '10^9/L');
      final parts = r.split(' - ');
      expect(double.parse(parts[0]), closeTo(4.0, 0.1));
      expect(double.parse(parts[1]), closeTo(11.0, 0.1));
    });
    
    test('Qualitative range returns original (Negative)', () {
      final r = UnitConverter.convertRange('proteins', 'Negative', 'mg/dL', 'mmol/L');
      expect(r, 'Negative');
    });

    test('Qualitative range with mixed text returns original', () {
      final r = UnitConverter.convertRange('urine_colour', 'Pale yellow to amber', '', '');
      expect(r, 'Pale yellow to amber');
    });

    test('Complex qualitative/numeric range returns original (Negative or < 15)', () {
      // The current convertRange function splits by ' - ' or checks for '<' or '>'.
      // For highly complex text strings, it will likely return the original if it fails to parse as simple numbers.
      final r = UnitConverter.convertRange('proteins', 'Negative or < 15', 'mg/dL', 'mmol/L');
      expect(r, 'Negative or < 15');
    });
  });

  group('UnitConverter - No-op cases', () {
    test('Same unit returns unchanged', () {
      final r = UnitConverter.convert('hemoglobin_g_dl', '15.0', 'g/dL', 'g/dL');
      expect(r.wasConverted, false);
      expect(r.convertedValue, '15.0');
    });
    test('Non-numeric value returns unchanged', () {
      final r = UnitConverter.convert('proteins', 'Negative', 'mg/dL', 'mmol/L');
      expect(r.wasConverted, false);
      expect(r.convertedValue, 'Negative');
    });
    test('Empty unit returns unchanged', () {
      final r = UnitConverter.convert('hemoglobin_g_dl', '15.0', '', 'g/L');
      expect(r.wasConverted, false);
    });
  });
}
