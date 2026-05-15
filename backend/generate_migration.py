columns = [
    "hemoglobin_g_dl", "rbc_count_mil_ul", "hematocrit_pct", "mcv_fl", "mch_pg", "mchc_g_dl", "rdw_cv_pct", 
    "rdw_sd_fl", "wbc_cells_ul", "neutrophils_pct", "lymphocytes_pct", "eosinophils_pct", 
    "monocytes_pct", "basophils_pct", "abs_neutrophils", "abs_lymphocytes", "abs_monocytes", 
    "abs_eosinophils", "abs_basophils", "platelet_count_x10_3_ul", "mpv_fl", "platelet_rdw_pct", 
    "pct_pct", "p_lcr_pct", "img_pct", "imm_pct", "iml_pct", "lic_pct", "total_cholesterol_mg_dl", 
    "hdl_mg_dl", "ldl_mg_dl", "vldl_mg_dl", "triglycerides_mg_dl", "non_hdl_mg_dl", 
    "total_hdl_ratio", "ldl_hdl_ratio", "hdl_ldl_ratio", "bilirubin_total_mg_dl", 
    "bilirubin_direct_mg_dl", "bilirubin_indirect_mg_dl", "alp_u_l", "alt_sgpt_u_l", 
    "ast_sgot_u_l", "ggt_u_l", "protein_total_g_dl", "albumin_g_dl", "globulin_g_dl", 
    "a_g_ratio", "creatinine_mg_dl", "urea_mg_dl", "bun_mg_dl", "bun_creatinine_ratio", 
    "sodium_mmol_l", "potassium_mmol_l", "chloride_mmol_l", "uric_acid_mg_dl", 
    "egfr_ml_min_173m2", "iron_ug_dl", "uibc_ug_dl", "tibc_ug_dl", "transferrin_saturation_pct", 
    "hba1c_pct", "estimated_avg_glucose_mg_dl", "hbf_pct", "urine_albumin_mg_l", 
    "urine_creatinine_mg_dl", "albumin_creatinine_ratio", "calcium_mg_dl", "phosphorus_mg_dl", 
    "tt3_ng_dl", "tt4_ug_dl", "tsh_uiu_ml", "fasting_glucose_mg_dl", "postprandial_glucose_mg_dl", 
    "fbs_mg_dl", "plbs_mg_dl"
]

sql = ""
for col in columns:
    sql += f"ALTER TABLE staging_medical_records ALTER COLUMN {col} TYPE NUMERIC USING NULLIF(REGEXP_REPLACE({col}, '[^0-9.]', '', 'g'), '')::numeric;\n"

print(sql)
