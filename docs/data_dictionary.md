# 📖 MedScan — Clinical Biomarker Data Dictionary & Unit Standards

## 1. Overview

MedScan utilizes a clinical data dictionary spanning **92+ standardized biomarkers** across 14 medical diagnostic categories. To support longitudinal aggregation, all extracted measurements are converted into standardized database storage units.

---

## 2. Document & Patient Demographics

| Field Key | SQL Data Type | Standard Name | Allowed Units / Format | Aliases | Clinical Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `staging_record_id` | `UUID PK` | Staging Record ID | UUID (Auto) | N/A | Unique database row primary key. |
| `medid` | `BIGINT` | Patient ID | Numeric digits | MRN, NRIC, Passport | Standardized numeric patient identifier. |
| `original_medid` | `TEXT` | Raw Patient ID | Text | Patient Ref, NRIC | Raw extracted patient ID string. |
| `labreference` | `TEXT` | Sample Reference | Text | Specimen ID, Sample No | Standardized laboratory tube sample identifier. |
| `original_labreference` | `TEXT` | Raw Lab Reference | Text | Lab No, Specimen No | Raw extracted specimen identifier. |
| `report_reference` | `TEXT` | Report Reference | Text | Accession No, Episode No | Unique report document number. |
| `lab` | `TEXT` | Lab / Clinic Name | Text | Laboratory, Hospital | Issuing clinical or pathology laboratory. |
| `collected` | `DATE` | Collection Date | `YYYY-MM-DD` | Drawn Date, Sample Date | Specimen collection date. |
| `time` | `TIME` | Collection Time | `HH:MM:SS` | Drawn Time, Col Time | Specimen collection timestamp (24h format). |
| `reported_time` | `TIME` | Reported Time | `HH:MM:SS` | Approved Time, Printed Time | Report sign-off timestamp (24h format). |
| `gender` | `TEXT` | Gender | `Male` \| `Female` | Sex | Standardized patient biological sex. |

---

## 3. Clinical Categories & Biomarker Specifications

### 3.1 Complete Blood Count (CBC)

| Field Key | Standard Unit | Conventional Range | SI Unit & Range | Aliases | Unit Conversion Formula |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `hemoglobin_g_dl` | `g/dL` | M: 13.8–17.2<br>F: 12.1–15.1 | `g/L` (121–172) | Hb, HGB, Haemoglobin | $\text{g/L} \div 10.0 = \text{g/dL}$ |
| `rbc_count_mil_ul` | `mil/uL` | M: 4.5–5.9<br>F: 4.1–5.1 | $10^{12}/\text{L}$ (4.1–5.9) | RBC, Red Blood Cells | $10^{12}/\text{L} \times 1.0 = \text{mil/uL}$ |
| `hematocrit_pct` | `%` | M: 40.7–50.3%<br>F: 36.1–44.3% | L/L (0.36–0.50) | HCT, PCV, Packed Cell Volume | $\text{L/L} \times 100 = \%$ |
| `mcv_fl` | `fL` | 80.0–100.0 | `fL` (80–100) | Mean Corpuscular Volume | Identical |
| `mch_pg` | `pg` | 27.0–33.0 | `pg` (27–33) | Mean Corpuscular Hemoglobin | Identical |
| `mchc_g_dl` | `g/dL` | 32.0–36.0 | `g/L` (320–360) | MCHC | $\text{g/L} \div 10.0 = \text{g/dL}$ |
| `rdw_cv_pct` | `%` | 11.5–14.5% | Fraction (0.115–0.145) | RDW, Red Cell Dist. Width | $\text{Fraction} \times 100 = \%$ |
| `rdw_sd_fl` | `fL` | 39.0–46.0 | `fL` (39–46) | RDW-SD | Identical |
| `wbc_cells_ul` | `cells/uL` | 4,000–11,000 | $10^9/\text{L}$ (4.0–11.0) | WBC, TLC, White Blood Cells | $10^9/\text{L} \times 1000.0 = \text{cells/uL}$ |
| `neutrophils_pct` | `%` | 40–60% | Fraction (0.40–0.60) | Neutrophils, Neut, Polys | $\text{Fraction} \times 100 = \%$ |
| `lymphocytes_pct` | `%` | 20–40% | Fraction (0.20–0.40) | Lymphocytes, Lymph | $\text{Fraction} \times 100 = \%$ |
| `eosinophils_pct` | `%` | 1–4% | Fraction (0.01–0.04) | Eosinophils, Eos | $\text{Fraction} \times 100 = \%$ |
| `monocytes_pct` | `%` | 2–8% | Fraction (0.02–0.08) | Monocytes, Mono | $\text{Fraction} \times 100 = \%$ |
| `basophils_pct` | `%` | 0.5–1.0% | Fraction (0.005–0.01) | Basophils, Baso | $\text{Fraction} \times 100 = \%$ |
| `abs_neutrophils` | `cells/uL` | 1,500–8,000 | $10^9/\text{L}$ (1.5–8.0) | ANC, Absolute Neutrophils | $10^9/\text{L} \times 1000.0 = \text{cells/uL}$ |
| `abs_lymphocytes` | `cells/uL` | 1,000–4,800 | $10^9/\text{L}$ (1.0–4.8) | ALC, Absolute Lymphocytes | $10^9/\text{L} \times 1000.0 = \text{cells/uL}$ |
| `abs_monocytes` | `cells/uL` | 200–1,000 | $10^9/\text{L}$ (0.2–1.0) | AMC, Absolute Monocytes | $10^9/\text{L} \times 1000.0 = \text{cells/uL}$ |
| `abs_eosinophils` | `cells/uL` | 0–500 | $10^9/\text{L}$ (0.0–0.5) | AEC, Absolute Eosinophils | $10^9/\text{L} \times 1000.0 = \text{cells/uL}$ |
| `abs_basophils` | `cells/uL` | 0–200 | $10^9/\text{L}$ (0.0–0.2) | ABC, Absolute Basophils | $10^9/\text{L} \times 1000.0 = \text{cells/uL}$ |

---

### 3.2 Lipid Profile

| Field Key | Standard Unit | Conventional Range | SI Unit & Range | Aliases | Unit Conversion Formula |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `total_cholesterol_mg_dl` | `mg/dL` | $< 200$ | `mmol/L` ($< 5.17$) | Total Cholesterol, TC, Chol | $\text{mmol/L} \times 38.67 = \text{mg/dL}$ |
| `hdl_mg_dl` | `mg/dL` | M: $> 40$, F: $> 50$ | `mmol/L` ($> 1.03$) | HDL, HDL-C | $\text{mmol/L} \times 38.67 = \text{mg/dL}$ |
| `ldl_mg_dl` | `mg/dL` | $< 100$ | `mmol/L` ($< 2.59$) | LDL, LDL-C | $\text{mmol/L} \times 38.67 = \text{mg/dL}$ |
| `vldl_mg_dl` | `mg/dL` | 2–30 | `mmol/L` (0.05–0.78) | VLDL, VLDL-C | $\text{mmol/L} \times 38.67 = \text{mg/dL}$ |
| `triglycerides_mg_dl` | `mg/dL` | $< 150$ | `mmol/L` ($< 1.69$) | Triglycerides, TG, Trig | $\text{mmol/L} \times 88.57 = \text{mg/dL}$ |
| `non_hdl_mg_dl` | `mg/dL` | $< 130$ | `mmol/L` ($< 3.36$) | Non-HDL Cholesterol | $\text{mmol/L} \times 38.67 = \text{mg/dL}$ |
| `total_hdl_ratio` | Ratio | $< 5.0$ | Ratio ($< 5.0$) | TC/HDL Ratio | Ratio (No conversion) |
| `ldl_hdl_ratio` | Ratio | $< 3.5$ | Ratio ($< 3.5$) | LDL/HDL Ratio | Ratio (No conversion) |

---

### 3.3 Kidney Function & Electrolytes

| Field Key | Standard Unit | Conventional Range | SI Unit & Range | Aliases | Unit Conversion Formula |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `creatinine_mg_dl` | `mg/dL` | 0.6–1.3 | `µmol/L` (53–115) | Creatinine, Serum Creatinine | $\text{µmol/L} \div 88.42 = \text{mg/dL}$ |
| `urea_mg_dl` | `mg/dL` | 13–43 | `mmol/L` (2.1–7.1) | Blood Urea, Urea | $\text{mmol/L} \times 6.006 = \text{mg/dL}$ |
| `bun_mg_dl` | `mg/dL` | 7–20 | `mmol/L` (2.5–7.1) | Blood Urea Nitrogen, BUN | $\text{mmol/L} \times 2.80 = \text{mg/dL}$ |
| `uric_acid_mg_dl` | `mg/dL` | M: 3.4–7.0<br>F: 2.4–6.0 | `µmol/L` (143–416) | Uric Acid, Urate | $\text{µmol/L} \div 59.48 = \text{mg/dL}$ |
| `sodium_mmol_l` | `mmol/L` | 135–145 | `mEq/L` (135–145) | Sodium, Na+ | $\text{mEq/L} \times 1.0 = \text{mmol/L}$ |
| `potassium_mmol_l` | `mmol/L` | 3.5–5.0 | `mEq/L` (3.5–5.0) | Potassium, K+ | $\text{mEq/L} \times 1.0 = \text{mmol/L}$ |
| `chloride_mmol_l` | `mmol/L` | 98–107 | `mEq/L` (98–107) | Chloride, Cl- | $\text{mEq/L} \times 1.0 = \text{mmol/L}$ |
| `egfr_ml_min_173m2`| `mL/min/1.73m²` | $> 90$ | `mL/s/1.73m²` ($> 1.5$) | eGFR, Glomerular Filtration | $\text{mL/s} \times 60.0 = \text{mL/min}$ |

---

### 3.4 Liver Function Profile

| Field Key | Standard Unit | Conventional Range | SI Unit & Range | Aliases | Unit Conversion Formula |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `bilirubin_total_mg_dl` | `mg/dL` | 0.2–1.2 | `µmol/L` (3.4–20.5) | Total Bilirubin, T. Bili | $\text{µmol/L} \div 17.1 = \text{mg/dL}$ |
| `bilirubin_direct_mg_dl`| `mg/dL` | 0.0–0.3 | `µmol/L` (0.0–5.1) | Direct Bilirubin, D. Bili | $\text{µmol/L} \div 17.1 = \text{mg/dL}$ |
| `alp_u_l` | `U/L` | 44–147 | `µkat/L` (0.73–2.45) | Alkaline Phosphatase, ALP | $\text{µkat/L} \times 60.0 = \text{U/L}$ |
| `alt_sgpt_u_l` | `U/L` | 7–56 | `µkat/L` (0.12–0.93) | ALT, SGPT, Alanine Trans. | $\text{µkat/L} \times 60.0 = \text{U/L}$ |
| `ast_sgot_u_l` | `U/L` | 10–40 | `µkat/L` (0.17–0.67) | AST, SGOT, Aspartate Trans. | $\text{µkat/L} \times 60.0 = \text{U/L}$ |
| `ggt_u_l` | `U/L` | 9–48 | `µkat/L` (0.15–0.80) | GGT, Gamma GT | $\text{µkat/L} \times 60.0 = \text{U/L}$ |
| `protein_total_g_dl` | `g/dL` | 6.0–8.3 | `g/L` (60–83) | Total Protein, TP | $\text{g/L} \div 10.0 = \text{g/dL}$ |
| `albumin_g_dl` | `g/dL` | 3.5–5.0 | `g/L` (35–50) | Albumin, Alb | $\text{g/L} \div 10.0 = \text{g/dL}$ |
| `globulin_g_dl` | `g/dL` | 2.0–3.5 | `g/L` (20–35) | Globulin, Glob | $\text{g/L} \div 10.0 = \text{g/dL}$ |

---

### 3.5 Diabetes & Glycemic Control

| Field Key | Standard Unit | Conventional Range | SI Unit & Range | Aliases | Unit Conversion Formula |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `fasting_glucose_mg_dl` | `mg/dL` | 70–99 | `mmol/L` (3.9–5.5) | Fasting Blood Sugar, FBS | $\text{mmol/L} \times 18.018 = \text{mg/dL}$ |
| `postprandial_glucose_mg_dl`| `mg/dL` | $< 140$ | `mmol/L` ($< 7.8$) | Post-Prandial Glucose, PPBS | $\text{mmol/L} \times 18.018 = \text{mg/dL}$ |
| `hba1c_pct` | `%` | 4.0–5.6% | `mmol/mol` (20–38) | Glycated Hemoglobin, A1c | $\text{IFCC} = (\% - 2.15) \times 10.929$ |
| `estimated_avg_glucose_mg_dl`| `mg/dL` | 68–114 | `mmol/L` (3.8–6.3) | eAG, Estimated Avg Glucose | $\text{mmol/L} \times 18.018 = \text{mg/dL}$ |

---

### 3.6 Thyroid Profile

| Field Key | Standard Unit | Conventional Range | SI Unit & Range | Aliases | Unit Conversion Formula |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `tt3_ng_dl` | `ng/dL` | 80–200 | `nmol/L` (1.2–3.1) | Total T3, Triiodothyronine | $\text{nmol/L} \times 65.1 = \text{ng/dL}$ |
| `tt4_ug_dl` | `µg/dL` | 4.5–12.0 | `nmol/L` (58–154) | Total T4, Thyroxine | $\text{nmol/L} \times 0.0777 = \text{µg/dL}$ |
| `tsh_uiu_ml` | `µIU/mL` | 0.4–4.0 | `mIU/L` (0.4–4.0) | TSH, Thyroid Stim. Hormone | $\text{mIU/L} \times 1.0 = \text{µIU/mL}$ |
