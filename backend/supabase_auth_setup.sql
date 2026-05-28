-- ============================================================
-- MedScan: Supabase Auth Tables Setup
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 1. Users table for app-level authentication
CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast email lookups during login
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- 2. Reports table for storing digitized files and structured metadata
CREATE TABLE IF NOT EXISTS reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filename        TEXT NOT NULL,
    upload_time     TIMESTAMPTZ NOT NULL DEFAULT now(),
    status          TEXT NOT NULL DEFAULT 'processing',
    raw_text        TEXT,
    structured_data JSONB,
    user_verified   INTEGER DEFAULT 0,
    file_path       TEXT
);

-- Ensure user_id column exists and links to users table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'reports' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE reports ADD COLUMN user_id UUID REFERENCES users(id);
    END IF;
END $$;

-- Index for fetching reports by user
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports (user_id);

-- 3. Chat Sessions table for medical chat history context
CREATE TABLE IF NOT EXISTS chat_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    title       TEXT NOT NULL
);

-- Index for fast session lookup by user
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions (user_id);

-- 4. Chat Messages table for session message log
CREATE TABLE IF NOT EXISTS chat_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role        TEXT NOT NULL,
    content     TEXT NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for message ordering per session
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON chat_messages (session_id);

-- 5. Enable Row Level Security (RLS) on all core tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Allow the API (anon / authenticated / service_role keys) full access.
-- Authentication and user isolation is validated server-side in the FastAPI service layer.
CREATE POLICY IF NOT EXISTS "Allow all access to users" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow all access to reports" ON reports FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow all access to chat_sessions" ON chat_sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Allow all access to chat_messages" ON chat_messages FOR ALL USING (true) WITH CHECK (true);

-- 6. Grant API privileges to anonymous, authenticated, and service roles
-- Required for Supabase projects created after May 30, 2026 where tables in the public schema are not exposed by default.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_sessions TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_messages TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE staging_medical_records TO anon, authenticated, service_role;

-- ============================================================
-- Done! Your Supabase tables are ready for MedScan auth.
-- ============================================================

-- Convert biomarker columns to numeric
ALTER TABLE staging_medical_records ALTER COLUMN hemoglobin_g_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(hemoglobin_g_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN rbc_count_mil_ul TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(rbc_count_mil_ul, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN hematocrit_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(hematocrit_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN mcv_fl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(mcv_fl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN mch_pg TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(mch_pg, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN mchc_g_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(mchc_g_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN rdw_cv_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(rdw_cv_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN rdw_sd_fl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(rdw_sd_fl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN wbc_cells_ul TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(wbc_cells_ul, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN neutrophils_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(neutrophils_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN lymphocytes_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(lymphocytes_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN eosinophils_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(eosinophils_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN monocytes_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(monocytes_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN basophils_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(basophils_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN abs_neutrophils TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(abs_neutrophils, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN abs_lymphocytes TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(abs_lymphocytes, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN abs_monocytes TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(abs_monocytes, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN abs_eosinophils TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(abs_eosinophils, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN abs_basophils TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(abs_basophils, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN platelet_count_x10_3_ul TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(platelet_count_x10_3_ul, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN mpv_fl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(mpv_fl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN platelet_rdw_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(platelet_rdw_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN pct_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(pct_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN p_lcr_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(p_lcr_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN img_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(img_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN imm_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(imm_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN iml_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(iml_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN lic_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(lic_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN total_cholesterol_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(total_cholesterol_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN hdl_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(hdl_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN ldl_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(ldl_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN vldl_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(vldl_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN triglycerides_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(triglycerides_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN non_hdl_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(non_hdl_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN total_hdl_ratio TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(total_hdl_ratio, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN ldl_hdl_ratio TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(ldl_hdl_ratio, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN hdl_ldl_ratio TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(hdl_ldl_ratio, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_total_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(bilirubin_total_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_direct_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(bilirubin_direct_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN bilirubin_indirect_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(bilirubin_indirect_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN alp_u_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(alp_u_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN alt_sgpt_u_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(alt_sgpt_u_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN ast_sgot_u_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(ast_sgot_u_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN ggt_u_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(ggt_u_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN protein_total_g_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(protein_total_g_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN albumin_g_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(albumin_g_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN globulin_g_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(globulin_g_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN a_g_ratio TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(a_g_ratio, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN creatinine_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(creatinine_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN urea_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(urea_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN bun_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(bun_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN bun_creatinine_ratio TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(bun_creatinine_ratio, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN sodium_mmol_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(sodium_mmol_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN potassium_mmol_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(potassium_mmol_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN chloride_mmol_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(chloride_mmol_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN uric_acid_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(uric_acid_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN egfr_ml_min_173m2 TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(egfr_ml_min_173m2, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN iron_ug_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(iron_ug_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN uibc_ug_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(uibc_ug_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN tibc_ug_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(tibc_ug_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN transferrin_saturation_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(transferrin_saturation_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN hba1c_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(hba1c_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN estimated_avg_glucose_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(estimated_avg_glucose_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN hbf_pct TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(hbf_pct, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN urine_albumin_mg_l TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(urine_albumin_mg_l, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN urine_creatinine_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(urine_creatinine_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN albumin_creatinine_ratio TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(albumin_creatinine_ratio, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN calcium_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(calcium_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN phosphorus_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(phosphorus_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN tt3_ng_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(tt3_ng_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN tt4_ug_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(tt4_ug_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN tsh_uiu_ml TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(tsh_uiu_ml, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN fasting_glucose_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(fasting_glucose_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN postprandial_glucose_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(postprandial_glucose_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN fbs_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(fbs_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;
ALTER TABLE staging_medical_records ALTER COLUMN plbs_mg_dl TYPE NUMERIC USING NULLIF(REGEXP_REPLACE(plbs_mg_dl, '[^0-9.]', '', 'g'), '')::numeric;


-- Create composite index
CREATE INDEX IF NOT EXISTS idx_staging_medid_collected ON staging_medical_records (medid, collected);

-- 5. Add health_summary column to users table for caching AI health summary
ALTER TABLE users ADD COLUMN IF NOT EXISTS health_summary TEXT;

