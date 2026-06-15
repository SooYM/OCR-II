# OCR II Data Dictionary

This document provides a comprehensive schema overview of the staging medical database and standard biomarkers extracted and mapped by the system. It covers database fields, SQL data types, target units, reference ranges, aliases, descriptions, and unit conversion algorithms.

---

## 1. Document & Patient Metadata Fields

These fields store the administrative, demographic, and hospital details extracted from the medical report.

| Database Field (Key) | SQL Data Type | Standard Name | Allowed Units / Format | Aliases | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `staging_record_id` | `UUID PRIMARY KEY` | Staging Record ID | UUID (Auto-generated) | N/A | Unique identifier for each database staging record. |
| `medid` | `BIGINT` | Patient ID | Numeric | N/A | Standardized identifier representing the patient. |
| `original_medid` | `TEXT NOT NULL` | Raw Patient ID | Text | Patient ID, MRN, NRIC, Passport No, Patient Ref | Original patient ID extracted directly from the report text. |
| `labreference` | `TEXT` | Lab Sample Reference | Text | N/A | Standardized laboratory sample/specimen reference identifier. |
| `original_labreference` | `TEXT NOT NULL` | Raw Lab Reference | Text | Lab No, Lab Number, Specimen No, Specimen ID, Sample ID, Sample No | Original sample identifier representing the physical blood/urine tube. |
| `report_reference` | `TEXT` | Report Reference | Text | Report No, Accession No, Episode No, Reference No, Ref No | Unique identification number for the printed report document itself. |
| `lab` | `TEXT` | Lab Name | Text | Laboratory | The name of the clinic, hospital, or laboratory that issued the report. |
| `collected` | `DATE` | Collection Date | `YYYY-MM-DD` | Collected Date, Drawn Date, Completed Date | The date the sample was collected. If collection date is missing, falls back to printed/reported date. |
| `time` | `TIME` | Collection Time | `HH:MM:SS` | Collected Time, Drawn Time, Date & Time Col | The time when the sample was drawn. Falls back to printed/reported time if missing. |
| `reported_time` | `TIME` | Reported Time | `HH:MM:SS` | Reported Time, Printed Time, Approved Date/Time | The time when the report was finalized, printed, or approved. |
| `gender` | `TEXT` | Gender | `Male` or `Female` | Sex | Standardized gender of the patient. |

---

## 2. Urinalysis Profile (`Urine`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `urine_colour` | `TEXT` | Urine Colour | None | Pale yellow to amber | N/A | None | Urine Color, Colour | Visual color of the urine sample. |
| `appearance` | `TEXT` | Appearance | None | Clear | N/A | None | Urine Appearance | Clarity or turbidity of the urine. |
| `specific_gravity` | `DOUBLE PRECISION` | Specific Gravity | None | 1.005 - 1.030 | N/A | None | Sp. Gravity, SG | Concentration of dissolved particles in urine. |
| `ph` | `DOUBLE PRECISION` | pH | None | 4.5 - 8.0 | N/A | None | Urine pH | Acidity or alkalinity level of the urine. |
| `proteins` | `TEXT` | Proteins | `mg/dL` | Negative or < 15 mg/dL | Negative or < 0.15 g/L | `mg/dL`, `g/L` | Urine Protein, Protein | Detection of protein in urine; indicates kidney status. |
| `glucose` | `TEXT` | Glucose (Urine) | None | Negative | Negative | None | Urine Glucose, Sugar | Detection of sugar in urine; common screening for diabetes. |
| `bilirubin` | `TEXT` | Bilirubin (Urine) | None | Negative | Negative | None | Urine Bilirubin | Bilirubin presence in urine; may indicate liver/bile issue. |
| `ketones` | `TEXT` | Ketones | None | Negative | Negative | None | Urine Ketones, Ketone Bodies | Detection of ketones from fat metabolism. |
| `blood` | `TEXT` | Blood (Urine) | None | Negative | Negative | None | Urine Blood, Occult Blood | Presence of blood/hemoglobin in urine. |
| `urobilinogen` | `TEXT` | Urobilinogen | `EU/dL` | 0.2 - 1.0 EU/dL or Normal | 3.4 - 17.0 µmol/L | `EU/dL`, `µmol/L` | Urine Urobilinogen | Byproduct of bilirubin breakdown. |
| `nitrites` | `TEXT` | Nitrites | None | Negative | Negative | None | Urine Nitrites, Nitrite | Often indicates presence of bacteria (UTI). |
| `wbc_pus_cells_hpf` | `TEXT` | WBC / Pus Cells | `/HPF` | 0 - 5 /HPF | 0 - 5 x 10^6/L | `/HPF`, `x10^6/L` | Pus Cells, WBC (Urine), Leucocytes | White blood cells per high-power field (infection marker). |
| `rbc` | `TEXT` | RBC (Urine) | `/HPF` | 0 - 2 /HPF | 0 - 2 x 10^6/L | `/HPF`, `x10^6/L` | Red Blood Cells (Urine) | Red blood cells per high-power field (hematuria marker). |
| `epithelial_cells_hpf` | `TEXT` | Epithelial Cells | `/HPF` | 0 - 5 /HPF | 0 - 5 x 10^6/L | `/HPF`, `x10^6/L` | Ep. Cells, Squamous Epithelial Cells | Cells shed from the urinary tract lining. |
| `casts` | `TEXT` | Casts | `/LPF` | Negative | Negative | `/LPF` | Urine Casts | Cylindrical structures formed in renal tubules. |
| `crystals` | `TEXT` | Crystals | None | Negative | Negative | None | Urine Crystals | Mineral crystals formed in urine. |
| `others` | `TEXT` | Others | None | Negative / Nil | Negative | None | Urine Others, Other | Any other elements observed under urine microscopy. |

---

## 3. Complete Blood Count (`CBC`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases / Dynamic Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `hemoglobin_g_dl` | `DOUBLE PRECISION` | Hemoglobin | `g/dL` | Male: 13.8 - 17.2<br>Female: 12.1 - 15.1 | Male: 138 - 172 g/L<br>Female: 121 - 151 g/L | `g/dL`, `g/L` | Hb, Haemoglobin, HGB, Hgb, hb | `g/L` &rarr; `g/dL`: Value / 10.0 |
| `rbc_count_mil_ul` | `DOUBLE PRECISION` | RBC Count | `mil/uL` | Male: 4.5 - 5.9<br>Female: 4.1 - 5.1 | Male: 4.5 - 5.9 × 10¹²/L<br>Female: 4.1 - 5.1 × 10¹²/L | `mil/uL`, `10^12/L` | Red Blood Cell Count, RBC, Erythrocyte Count, rbc | `10^12/L` &rarr; `mil/uL`: 1:1 ratio |
| `hematocrit_pct` | `DOUBLE PRECISION` | Hematocrit | `%` | Male: 40.7% - 50.3%<br>Female: 36.1% - 44.3% | Male: 0.407 - 0.503 L/L<br>Female: 0.361 - 0.443 L/L | `%`, `fraction`, `L/L` | HCT, Haematocrit, PCV, Packed Cell Volume | standard scaling |
| `mcv_fl` | `DOUBLE PRECISION` | MCV | `fL` | 80 - 100 fL | 80 - 100 fL | `fL` | Mean Corpuscular Volume | N/A |
| `mch_pg` | `BIGINT` | MCH | `pg` | 27 - 33 pg | 27 - 33 pg | `pg` | Mean Corpuscular Hemoglobin | N/A |
| `mchc_g_dl` | `DOUBLE PRECISION` | MCHC | `g/dL` | 32 - 36 g/dL | 320 - 360 g/L | `g/dL`, `g/L` | Mean Corpuscular Hemoglobin Concentration | `g/L` &rarr; `g/dL`: Value / 10.0 |
| `rdw_cv_pct` | `DOUBLE PRECISION` | RDW-CV | `%` | 11.5% - 14.5% | 0.115 - 0.145 fraction | `%` | RDW, Red Cell Distribution Width | standard scaling |
| `rdw_sd_fl` | `DOUBLE PRECISION` | RDW-SD | `fL` | 39 - 46 fL | 39 - 46 fL | `fL` | None | N/A |
| `wbc_cells_ul` | `BIGINT` | WBC | `cells/uL` | 4,000 - 11,000 | 4.0 - 11.0 × 10^9/L | `cells/uL`, `10^9/L` | White Blood Cell Count, TLC, Total Leucocyte Count, Leucocytes, wbc | `10^9/L` &rarr; `cells/uL`: Value * 1000.0 |
| `neutrophils_pct` | `BIGINT` | Neutrophils | `%` | 40% - 60% | 0.40 - 0.60 fraction | `%` | Neutrophil, Neut, Segmented Neutrophils, Polymorphs, neut | standard scaling |
| `lymphocytes_pct` | `BIGINT` | Lymphocytes | `%` | 20% - 40% | 0.20 - 0.40 fraction | `%` | Lymphocyte, Lymph | standard scaling |
| `eosinophils_pct` | `BIGINT` | Eosinophils | `%` | 1% - 4% | 0.01 - 0.04 fraction | `%` | Eosinophil, Eosino, Eos | standard scaling |
| `monocytes_pct` | `BIGINT` | Monocytes | `%` | 2% - 8% | 0.02 - 0.08 fraction | `%` | Monocyte, Mono | standard scaling |
| `basophils_pct` | `DOUBLE PRECISION` | Basophils | `%` | 0.5% - 1% | 0.005 - 0.01 fraction | `%` | Basophil, Baso | standard scaling |
| `abs_neutrophils` | `DOUBLE PRECISION` | Abs. Neutrophils | `cells/uL` | 1,500 - 8,000 | 1.5 - 8.0 × 10^9/L | `cells/uL`, `10^9/L` | ANC, Absolute Neutrophil Count | `10^9/L` &rarr; `cells/uL`: Value * 1000.0 |
| `abs_lymphocytes` | `DOUBLE PRECISION` | Abs. Lymphocytes | `cells/uL` | 1,000 - 4,800 | 1.0 - 4.8 × 10^9/L | `cells/uL`, `10^9/L` | ALC, Absolute Lymphocyte Count | `10^9/L` &rarr; `cells/uL`: Value * 1000.0 |
| `abs_monocytes` | `DOUBLE PRECISION` | Abs. Monocytes | `cells/uL` | 200 - 1,000 | 0.2 - 1.0 × 10^9/L | `cells/uL`, `10^9/L` | Absolute Monocyte Count | `10^9/L` &rarr; `cells/uL`: Value * 1000.0 |
| `abs_eosinophils` | `DOUBLE PRECISION` | Abs. Eosinophils | `cells/uL` | 0 - 500 | 0.0 - 0.5 × 10^9/L | `cells/uL`, `10^9/L` | AEC, Absolute Eosinophil Count | `10^9/L` &rarr; `cells/uL`: Value * 1000.0 |
| `abs_basophils` | `DOUBLE PRECISION` | Abs. Basophils | `cells/uL` | 0 - 200 | 0.0 - 0.2 × 10^9/L | `cells/uL`, `10^9/L` | Absolute Basophil Count | `10^9/L` &rarr; `cells/uL`: Value * 1000.0 |

---

## 4. Platelet Profile (`Platelet Profile`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases / Dynamic Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `platelet_count_x10_3_ul` | `BIGINT` | Platelet Count | `x10³/uL` | 150 - 450 × 10³/µL | 150 - 450 × 10^9/L | `x10³/uL`, `10^9/L` | PLT, Platelets, Thrombocyte Count, plt | `10^9/L` &rarr; `x10³/uL`: 1:1 ratio |
| `mpv_fl` | `DOUBLE PRECISION` | MPV | `fL` | 7.5 - 11.5 fL | 7.5 - 11.5 fL | `fL` | Mean Platelet Volume | N/A |
| `platelet_rdw_pct` | `BIGINT` | Platelet RDW | `%` | 9% - 17% | 0.09 - 0.17 fraction | `%` | PDW, Platelet Distribution Width | standard scaling |
| `pct_pct` | `DOUBLE PRECISION` | PCT | `%` | 0.17% - 0.35% | 1.7 - 3.5 mL/L | `%` | Plateletcrit | N/A |
| `p_lcr_pct` | `DOUBLE PRECISION` | P-LCR | `%` | 13% - 43% | 0.13 - 0.43 fraction | `%` | Platelet Large Cell Ratio | N/A |
| `img_pct` | `DOUBLE PRECISION` | IMG | `%` | 0% - 0.5% | 0.0 - 0.005 fraction | `%` | None | N/A |
| `imm_pct` | `DOUBLE PRECISION` | IMM | `%` | 0% - 0.5% | 0.0 - 0.005 fraction | `%` | None | N/A |
| `iml_pct` | `DOUBLE PRECISION` | IML | `%` | 0% - 0.5% | 0.0 - 0.005 fraction | `%` | None | N/A |
| `lic_pct` | `DOUBLE PRECISION` | LIC | `%` | 0% - 2.5% | 0.0 - 0.025 fraction | `%` | None | N/A |

---

## 5. Lipid Profile (`Lipid Profile`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `total_cholesterol_mg_dl` | `BIGINT` | Total Cholesterol | `mg/dL` | < 200 mg/dL | < 5.17 mmol/L | `mg/dL`, `mmol/L` | Cholesterol, Tot. Cholesterol, TC, Chol, S. Cholesterol, Serum Cholesterol | `mmol/L` &rarr; `mg/dL`: Value * 38.67 |
| `hdl_mg_dl` | `BIGINT` | HDL Cholesterol | `mg/dL` | Male: > 40<br>Female: > 50 | Male: > 1.03 mmol/L<br>Female: > 1.29 mmol/L | `mg/dL`, `mmol/L` | HDL, HDL-C, High Density Lipoprotein | `mmol/L` &rarr; `mg/dL`: Value * 38.67 |
| `ldl_mg_dl` | `DOUBLE PRECISION` | LDL Cholesterol | `mg/dL` | < 100 mg/dL | < 2.59 mmol/L | `mg/dL`, `mmol/L` | LDL, LDL-C, Low Density Lipoprotein | `mmol/L` &rarr; `mg/dL`: Value * 38.67 |
| `vldl_mg_dl` | `TEXT` | VLDL Cholesterol | `mg/dL` | 2 - 30 mg/dL | 0.05 - 0.78 mmol/L | `mg/dL`, `mmol/L` | VLDL, VLDL-C, Very Low Density Lipoprotein | `mmol/L` &rarr; `mg/dL`: Value * 38.67 |
| `triglycerides_mg_dl` | `TEXT` | Triglycerides | `mg/dL` | < 150 mg/dL | < 1.69 mmol/L | `mg/dL`, `mmol/L` | TG, Trigs, Triglyceride, S. Triglycerides | `mmol/L` &rarr; `mg/dL`: Value * 88.57 |
| `non_hdl_mg_dl` | `BIGINT` | Non-HDL Cholesterol | `mg/dL` | < 130 mg/dL | < 3.36 mmol/L | `mg/dL`, `mmol/L` | Non HDL, Non-HDL | `mmol/L` &rarr; `mg/dL`: Value * 38.67 |
| `total_hdl_ratio` | `DOUBLE PRECISION` | Total/HDL Ratio | None | < 5.0 (Optimal < 3.5) | < 5.0 | None | TC/HDL, Cholesterol/HDL Ratio | N/A |
| `ldl_hdl_ratio` | `DOUBLE PRECISION` | LDL/HDL Ratio | None | < 3.0 | < 3.0 | None | None | N/A |
| `hdl_ldl_ratio` | `DOUBLE PRECISION` | HDL/LDL Ratio | None | N/A | N/A | None | None | N/A (Staging DB field only, not mapped in dictionary UI) |

---

## 6. Liver Function Profile (`Liver Function`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `bilirubin_total_mg_dl` | `DOUBLE PRECISION` | Bilirubin Total | `mg/dL` | 0.1 - 1.2 mg/dL | 1.7 - 20.5 µmol/L | `mg/dL`, `umol/L`, `µmol/L` | Total Bilirubin, T. Bilirubin, S. Bilirubin | `µmol/L` &rarr; `mg/dL`: Value / 17.1 |
| `bilirubin_direct_mg_dl` | `DOUBLE PRECISION` | Bilirubin Direct | `mg/dL` | < 0.3 mg/dL | < 5.1 µmol/L | `mg/dL`, `umol/L`, `µmol/L` | Direct Bilirubin, Conjugated Bilirubin | `µmol/L` &rarr; `mg/dL`: Value / 17.1 |
| `bilirubin_indirect_mg_dl` | `DOUBLE PRECISION` | Bilirubin Indirect | `mg/dL` | 0.1 - 1.0 mg/dL | 1.7 - 17.1 µmol/L | `mg/dL`, `umol/L`, `µmol/L` | Indirect Bilirubin, Unconjugated Bilirubin | `µmol/L` &rarr; `mg/dL`: Value / 17.1 |
| `alp_u_l` | `BIGINT` | ALP | `U/L` | 44 - 147 U/L | 0.73 - 2.45 µkat/L | `U/L`, `µkat/L` | Alkaline Phosphatase, Alk. Phosphatase | `µkat/L` &rarr; `U/L`: Value * 60.0 |
| `alt_sgpt_u_l` | `BIGINT` | ALT (SGPT) | `U/L` | 7 - 56 U/L | 0.12 - 0.93 µkat/L | `U/L`, `µkat/L` | ALT, SGPT, Alanine Aminotransferase, Alanine Transaminase | `µkat/L` &rarr; `U/L`: Value * 60.0 |
| `ast_sgot_u_l` | `BIGINT` | AST (SGOT) | `U/L` | 8 - 48 U/L | 0.13 - 0.80 µkat/L | `U/L`, `µkat/L` | AST, SGOT, Aspartate Aminotransferase, Aspartate Transaminase | `µkat/L` &rarr; `U/L`: Value * 60.0 |
| `ggt_u_l` | `BIGINT` | GGT | `U/L` | 9 - 48 U/L | 0.15 - 0.80 µkat/L | `U/L`, `µkat/L` | Gamma GT, Gamma Glutamyl Transferase, Gamma-Glutamyl Transpeptidase | `µkat/L` &rarr; `U/L`: Value * 60.0 |
| `protein_total_g_dl` | `DOUBLE PRECISION` | Total Protein | `g/dL` | 6.0 - 8.3 g/dL | 60 - 83 g/L | `g/dL`, `g/L` | Protein Total, S. Protein, Serum Protein, Total Proteins | `g/L` &rarr; `g/dL`: Value / 10.0 |
| `albumin_g_dl` | `DOUBLE PRECISION` | Albumin | `g/dL` | 3.4 - 5.4 g/dL | 34 - 54 g/L | `g/dL`, `g/L` | S. Albumin, Serum Albumin, Alb | `g/L` &rarr; `g/dL`: Value / 10.0 |
| `globulin_g_dl` | `DOUBLE PRECISION` | Globulin | `g/dL` | 2.0 - 3.5 g/dL | 20 - 35 g/L | `g/dL`, `g/L` | S. Globulin, Serum Globulin | `g/L` &rarr; `g/dL`: Value / 10.0 |
| `a_g_ratio` | `TEXT` | A/G Ratio | None | 1.1 - 2.5 | 1.1 - 2.5 | None | Albumin/Globulin Ratio, AG Ratio | N/A |

---

## 7. Kidney Function Profile (`Kidney Function`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `creatinine_mg_dl` | `DOUBLE PRECISION` | Creatinine | `mg/dL` | Male: 0.74 - 1.35<br>Female: 0.59 - 1.04 | Male: 65.4 - 119.3 µmol/L<br>Female: 52.2 - 91.9 µmol/L | `mg/dL`, `umol/L`, `µmol/L` | S. Creatinine, Serum Creatinine, Creat | `µmol/L` &rarr; `mg/dL`: Value / 88.42 |
| `urea_mg_dl` | `DOUBLE PRECISION` | Urea | `mg/dL` | 15 - 40 mg/dL | 2.5 - 6.7 mmol/L | `mg/dL`, `mmol/L` | Blood Urea, S. Urea, Serum Urea | `mmol/L` &rarr; `mg/dL`: Value * 6.006 |
| `bun_mg_dl` | `DOUBLE PRECISION` | BUN | `mg/dL` | 7 - 20 mg/dL | 2.5 - 7.1 mmol/L | `mg/dL`, `mmol/L` | Blood Urea Nitrogen | `mmol/L` &rarr; `mg/dL`: Value * 2.8 |
| `bun_creatinine_ratio` | `DOUBLE PRECISION` | BUN/Creatinine Ratio | None | 10:1 - 20:1 | 40:1 - 80:1 mmol/mmol | None | None | N/A |
| `sodium_mmol_l` | `BIGINT` | Sodium | `mmol/L` | 135 - 145 mmol/L | 135 - 145 mmol/L | `mmol/L`, `mEq/L` | Na, Na+, S. Sodium, Serum Sodium | `mEq/L` &rarr; `mmol/L`: 1:1 ratio |
| `potassium_mmol_l` | `DOUBLE PRECISION` | Potassium | `mmol/L` | 3.5 - 5.0 mmol/L | 3.5 - 5.0 mmol/L | `mmol/L`, `mEq/L` | K, K+, S. Potassium, Serum Potassium | `mEq/L` &rarr; `mmol/L`: 1:1 ratio |
| `chloride_mmol_l` | `BIGINT` | Chloride | `mmol/L` | 96 - 106 mmol/L | 96 - 106 mmol/L | `mmol/L`, `mEq/L` | Cl, Cl-, S. Chloride, Serum Chloride | `mEq/L` &rarr; `mmol/L`: 1:1 ratio |
| `uric_acid_mg_dl` | `DOUBLE PRECISION` | Uric Acid | `mg/dL` | Male: 3.4 - 7.0<br>Female: 2.4 - 6.0 | Male: 202 - 416 µmol/L<br>Female: 143 - 357 µmol/L | `mg/dL`, `µmol/L` | S. Uric Acid, Serum Uric Acid | `µmol/L` &rarr; `mg/dL`: Value / 59.48 |
| `egfr_ml_min_173m2` | `DOUBLE PRECISION` | eGFR | `mL/min/1.73m²` | > 90 mL/min/1.73m² | > 1.5 mL/s/1.73m² | `mL/min/1.73m²`, `mL/s/1.73m²` | Estimated GFR, Glomerular Filtration Rate, egfr | `mL/s/1.73m²` &rarr; `mL/min/1.73m²`: Value * 60.0 |

---

## 8. Iron Profile (`Iron Profile`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `iron_ug_dl` | `BIGINT` | Iron | `ug/dL` | Male: 65 - 176<br>Female: 50 - 170 | Male: 11.6 - 31.5 µmol/L<br>Female: 9.0 - 30.4 µmol/L | `ug/dL`, `umol/L`, `µmol/L` | S. Iron, Serum Iron, Fe | `µmol/L` &rarr; `ug/dL`: Value * 5.59 |
| `uibc_ug_dl` | `BIGINT` | UIBC | `ug/dL` | 112 - 346 µg/dL | 20.0 - 61.9 µmol/L | `ug/dL`, `umol/L`, `µmol/L` | Unsaturated Iron Binding Capacity | `µmol/L` &rarr; `ug/dL`: Value * 5.59 |
| `tibc_ug_dl` | `BIGINT` | TIBC | `ug/dL` | 240 - 450 µg/dL | 42.9 - 80.6 µmol/L | `ug/dL`, `umol/L`, `µmol/L` | Total Iron Binding Capacity | `µmol/L` &rarr; `ug/dL`: Value * 5.59 |
| `transferrin_saturation_pct` | `DOUBLE PRECISION` | Transferrin Saturation | `%` | 20% - 50% | 0.20 - 0.50 fraction | `%` | TSAT, Iron Saturation | standard scaling |

---

## 9. HbA1c & Glucose Profiles

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **HbA1c Profile** | | | | | | | | |
| `hba1c_pct` | `DOUBLE PRECISION` | HbA1c | `%` | < 5.7% | < 39 mmol/mol | `%`, `mmol/mol` | Glycated Hemoglobin, Glycosylated Hemoglobin, A1C, Glycated Haemoglobin | `mmol/mol` &rarr; `%`: `(Value * 0.09148) + 2.152` |
| `estimated_avg_glucose_mg_dl` | `DOUBLE PRECISION` | Estimated Avg. Glucose | `mg/dL` | < 117 mg/dL | < 6.5 mmol/L | `mg/dL`, `mmol/L` | eAG, Estimated Average Glucose | `mmol/L` &rarr; `mg/dL`: Value * 18.018 |
| `hbf_pct` | `DOUBLE PRECISION` | HbF | `%` | < 2.0% | < 0.02 fraction | `%` | Fetal Hemoglobin | standard scaling |
| **Glucose Profiles** | | | | | | | | |
| `fasting_glucose_mg_dl` | `BIGINT` | Fasting Glucose | `mg/dL` | 70 - 99 mg/dL | 3.9 - 5.5 mmol/L | `mg/dL`, `mmol/L` | FBS, Fasting Blood Sugar, Fasting Blood Glucose, Glucose Fasting, F. Glucose | `mmol/L` &rarr; `mg/dL`: Value * 18.018 |
| `postprandial_glucose_mg_dl` | `BIGINT` | Postprandial Glucose | `mg/dL` | < 140 mg/dL | < 7.8 mmol/L | `mg/dL`, `mmol/L` | PPBS, PP Blood Sugar, PP Glucose, Post Prandial Blood Sugar, Glucose PP | `mmol/L` &rarr; `mg/dL`: Value * 18.018 |
| `fbs_mg_dl` | `BIGINT` | FBS | `mg/dL` | 70 - 99 mg/dL | 3.9 - 5.5 mmol/L | `mg/dL`, `mmol/L` | Fasting Blood Sugar | `mmol/L` &rarr; `mg/dL`: Value * 18.018 |
| `plbs_mg_dl` | `BIGINT` | PLBS | `mg/dL` | < 140 mg/dL | < 7.8 mmol/L | `mg/dL`, `mmol/L` | Post Lunch Blood Sugar | `mmol/L` &rarr; `mg/dL`: Value * 18.018 |

---

## 10. Urine ACR & Calcium/Phosphorus Profiles

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Urine ACR Profile** | | | | | | | | |
| `urine_albumin_mg_l` | `DOUBLE PRECISION` | Urine Albumin | `mg/L` | < 30 mg/L | < 30 mg/L | `mg/L` | Microalbumin, U. Albumin | N/A |
| `urine_creatinine_mg_dl` | `DOUBLE PRECISION` | Urine Creatinine | `mg/dL` | Male: 20 - 275<br>Female: 15 - 225 | Male: 1.77 - 24.3 mmol/L<br>Female: 1.33 - 19.9 mmol/L | `mg/dL`, `mmol/L` | U. Creatinine | `mmol/L` &rarr; `mg/dL`: Value * 11.312 |
| `albumin_creatinine_ratio` | `DOUBLE PRECISION` | Albumin/Creatinine Ratio | None | < 30 mg/g | < 3.4 mg/mmol | `mg/g`, `mg/mmol` | ACR, Urine ACR | N/A |
| **Calcium & Phos** | | | | | | | | |
| `calcium_mg_dl` | `DOUBLE PRECISION` | Calcium | `mg/dL` | 8.5 - 10.2 mg/dL | 2.12 - 2.55 mmol/L | `mg/dL`, `mmol/L` | Ca, Ca++, S. Calcium, Serum Calcium, Total Calcium | `mmol/L` &rarr; `mg/dL`: Value * 4.0 |
| `phosphorus_mg_dl` | `DOUBLE PRECISION` | Phosphorus | `mg/dL` | 2.5 - 4.5 mg/dL | 0.81 - 1.45 mmol/L | `mg/dL`, `mmol/L` | Phosphate, Phos, S. Phosphorus, Inorganic Phosphorus | `mmol/L` &rarr; `mg/dL`: Value * 3.097 |

---

## 11. Thyroid Profile (`Thyroid Profile`)

| Database Field (Key) | SQL Data Type | Standard Name | Standard Unit | Reference Range (Conv.) | Reference Range (SI) | Allowed Units | Aliases | Conversion Logic (SI &rarr; Conventional) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `tt3_ng_dl` | `BIGINT` | Total T3 | `ng/dL` | 80 - 200 ng/dL | 1.2 - 3.1 nmol/L | `ng/dL`, `nmol/L` | T3, TT3, Triiodothyronine | `nmol/L` &rarr; `ng/dL`: Value / 0.01536 |
| `tt4_ug_dl` | `DOUBLE PRECISION` | Total T4 | `ug/dL` | 5.0 - 12.0 µg/dL | 64 - 154 nmol/L | `ug/dL`, `nmol/L` | T4, TT4, Thyroxine | `nmol/L` &rarr; `ug/dL`: Value / 12.87 |
| `tsh_uiu_ml` | `DOUBLE PRECISION` | TSH | `uIU/mL` | 0.4 - 4.0 µIU/mL | 0.4 - 4.0 mIU/L | `uIU/mL`, `mIU/L` | Thyroid Stimulating Hormone, Thyrotropin | `mIU/L` &rarr; `uIU/mL`: 1:1 ratio |
