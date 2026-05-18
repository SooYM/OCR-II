-- Schema Migration: Make columns nullable and change types with safe casting to TEXT then to DOUBLE PRECISION then BIGINT

ALTER TABLE staging_medical_records ALTER COLUMN medid DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN labreference DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN sample_id DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN collected DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN time DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN reported_time DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN urine_colour DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN appearance DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN specific_gravity DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN ph DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN proteins DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN glucose DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN ketones DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN blood DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN urobilinogen DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN nitrites DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN wbc_pus_cells_hpf DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN rbc DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN epithelial_cells_hpf DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN casts DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN crystals DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN others DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN hemoglobin_g_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN rbc_count_mil_ul DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN hematocrit_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN mcv_fl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN mch_pg DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN mchc_g_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN rdw_cv_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN rdw_sd_fl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN wbc_cells_ul DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN neutrophils_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN lymphocytes_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN eosinophils_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN monocytes_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN basophils_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN abs_neutrophils DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN abs_lymphocytes DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN abs_monocytes DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN abs_eosinophils DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN abs_basophils DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN platelet_count_x10_3_ul DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN mpv_fl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN platelet_rdw_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN pct_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN p_lcr_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN img_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN imm_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN iml_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN lic_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN total_cholesterol_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN hdl_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN ldl_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN vldl_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN triglycerides_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN non_hdl_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN total_hdl_ratio DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN ldl_hdl_ratio DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN hdl_ldl_ratio DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_total_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_direct_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_indirect_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN alp_u_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN alt_sgpt_u_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN ast_sgot_u_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN ggt_u_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN protein_total_g_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN albumin_g_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN globulin_g_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN a_g_ratio DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN creatinine_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN urea_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN bun_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN bun_creatinine_ratio DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN sodium_mmol_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN potassium_mmol_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN chloride_mmol_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN uric_acid_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN egfr_ml_min_173m2 DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN iron_ug_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN uibc_ug_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN tibc_ug_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN transferrin_saturation_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN hba1c_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN estimated_avg_glucose_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN hbf_pct DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN urine_albumin_mg_l DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN urine_creatinine_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN albumin_creatinine_ratio DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN calcium_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN phosphorus_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN tt3_ng_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN tt4_ug_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN tsh_uiu_ml DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN fasting_glucose_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN postprandial_glucose_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN fbs_mg_dl DROP NOT NULL;
ALTER TABLE staging_medical_records ALTER COLUMN plbs_mg_dl DROP NOT NULL;

ALTER TABLE staging_medical_records ALTER COLUMN medid TYPE BIGINT USING NULLIF(REGEXP_REPLACE(medid::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN sample_id TYPE BIGINT USING NULLIF(REGEXP_REPLACE(sample_id::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN collected TYPE DATE USING 
    CASE 
        WHEN NULLIF(TRIM(collected::TEXT), '') IS NULL THEN NULL
        WHEN collected::TEXT ~ '^\d{4}-\d{2}-\d{2}' THEN SUBSTRING(collected::TEXT FROM 1 FOR 10)::DATE
        WHEN collected::TEXT ~ '^\d{2}/\d{2}/\d{4}' THEN TO_DATE(SUBSTRING(collected::TEXT FROM 1 FOR 10), 'DD/MM/YYYY')
        WHEN collected::TEXT ~ '^\d{2}-\d{2}-\d{4}' THEN TO_DATE(SUBSTRING(collected::TEXT FROM 1 FOR 10), 'DD-MM-YYYY')
        ELSE NULL
    END;
ALTER TABLE staging_medical_records ALTER COLUMN time TYPE TIME USING 
    CASE 
        WHEN NULLIF(TRIM(time::TEXT), '') IS NULL THEN NULL
        WHEN time::TEXT ~ '\s(\d{2}:\d{2}(:\d{2})?)$' THEN (REGEXP_MATCH(time::TEXT, '\s(\d{2}:\d{2}(:\d{2})?)$'))[1]::TIME
        WHEN time::TEXT ~ '^\d{2}:\d{2}(:\d{2})?' THEN (REGEXP_MATCH(time::TEXT, '^\d{2}:\d{2}(:\d{2})?'))[1]::TIME
        ELSE NULL
    END;
ALTER TABLE staging_medical_records ALTER COLUMN reported_time TYPE TIME USING 
    CASE 
        WHEN NULLIF(TRIM(reported_time::TEXT), '') IS NULL THEN NULL
        WHEN reported_time::TEXT ~ '\s(\d{2}:\d{2}(:\d{2})?)$' THEN (REGEXP_MATCH(reported_time::TEXT, '\s(\d{2}:\d{2}(:\d{2})?)$'))[1]::TIME
        WHEN reported_time::TEXT ~ '^\d{2}:\d{2}(:\d{2})?' THEN (REGEXP_MATCH(reported_time::TEXT, '^\d{2}:\d{2}(:\d{2})?'))[1]::TIME
        ELSE NULL
    END;
ALTER TABLE staging_medical_records ALTER COLUMN specific_gravity TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(specific_gravity::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN ph TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(ph::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN hemoglobin_g_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(hemoglobin_g_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN rbc_count_mil_ul TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(rbc_count_mil_ul::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN hematocrit_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(hematocrit_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN mcv_fl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(mcv_fl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN mch_pg TYPE BIGINT USING NULLIF(REGEXP_REPLACE(mch_pg::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN mchc_g_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(mchc_g_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN rdw_cv_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(rdw_cv_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN rdw_sd_fl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(rdw_sd_fl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN wbc_cells_ul TYPE BIGINT USING NULLIF(REGEXP_REPLACE(wbc_cells_ul::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN neutrophils_pct TYPE BIGINT USING NULLIF(REGEXP_REPLACE(neutrophils_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN lymphocytes_pct TYPE BIGINT USING NULLIF(REGEXP_REPLACE(lymphocytes_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN eosinophils_pct TYPE BIGINT USING NULLIF(REGEXP_REPLACE(eosinophils_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN monocytes_pct TYPE BIGINT USING NULLIF(REGEXP_REPLACE(monocytes_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN basophils_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(basophils_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN abs_neutrophils TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(abs_neutrophils::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN abs_lymphocytes TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(abs_lymphocytes::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN abs_monocytes TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(abs_monocytes::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN abs_eosinophils TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(abs_eosinophils::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN abs_basophils TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(abs_basophils::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN platelet_count_x10_3_ul TYPE BIGINT USING NULLIF(REGEXP_REPLACE(platelet_count_x10_3_ul::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN mpv_fl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(mpv_fl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN platelet_rdw_pct TYPE BIGINT USING NULLIF(REGEXP_REPLACE(platelet_rdw_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN pct_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(pct_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN p_lcr_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(p_lcr_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN img_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(img_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN imm_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(imm_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN iml_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(iml_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN lic_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(lic_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN total_cholesterol_mg_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(total_cholesterol_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN hdl_mg_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(hdl_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN ldl_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(ldl_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN non_hdl_mg_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(non_hdl_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN total_hdl_ratio TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(total_hdl_ratio::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN ldl_hdl_ratio TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(ldl_hdl_ratio::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN hdl_ldl_ratio TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(hdl_ldl_ratio::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_total_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(bilirubin_total_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_direct_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(bilirubin_direct_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_indirect_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(bilirubin_indirect_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN alp_u_l TYPE BIGINT USING NULLIF(REGEXP_REPLACE(alp_u_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN alt_sgpt_u_l TYPE BIGINT USING NULLIF(REGEXP_REPLACE(alt_sgpt_u_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN ast_sgot_u_l TYPE BIGINT USING NULLIF(REGEXP_REPLACE(ast_sgot_u_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN ggt_u_l TYPE BIGINT USING NULLIF(REGEXP_REPLACE(ggt_u_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN protein_total_g_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(protein_total_g_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN albumin_g_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(albumin_g_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN globulin_g_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(globulin_g_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN creatinine_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(creatinine_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN urea_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(urea_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN bun_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(bun_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN bun_creatinine_ratio TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(bun_creatinine_ratio::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN sodium_mmol_l TYPE BIGINT USING NULLIF(REGEXP_REPLACE(sodium_mmol_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN potassium_mmol_l TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(potassium_mmol_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN chloride_mmol_l TYPE BIGINT USING NULLIF(REGEXP_REPLACE(chloride_mmol_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN uric_acid_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(uric_acid_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN egfr_ml_min_173m2 TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(egfr_ml_min_173m2::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN iron_ug_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(iron_ug_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN uibc_ug_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(uibc_ug_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN tibc_ug_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(tibc_ug_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN transferrin_saturation_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(transferrin_saturation_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN hba1c_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(hba1c_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN estimated_avg_glucose_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(estimated_avg_glucose_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN hbf_pct TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(hbf_pct::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN urine_albumin_mg_l TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(urine_albumin_mg_l::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN urine_creatinine_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(urine_creatinine_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN albumin_creatinine_ratio TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(albumin_creatinine_ratio::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN calcium_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(calcium_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN phosphorus_mg_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(phosphorus_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN tt3_ng_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(tt3_ng_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN tt4_ug_dl TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(tt4_ug_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN tsh_uiu_ml TYPE DOUBLE PRECISION USING NULLIF(REGEXP_REPLACE(tsh_uiu_ml::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION;
ALTER TABLE staging_medical_records ALTER COLUMN fasting_glucose_mg_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(fasting_glucose_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN postprandial_glucose_mg_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(postprandial_glucose_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN fbs_mg_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(fbs_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
ALTER TABLE staging_medical_records ALTER COLUMN plbs_mg_dl TYPE BIGINT USING NULLIF(REGEXP_REPLACE(plbs_mg_dl::TEXT, '[^0-9.]', '', 'g'), '')::DOUBLE PRECISION::BIGINT;
