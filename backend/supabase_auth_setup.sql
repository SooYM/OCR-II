-- ============================================================
-- MedScan: Master PostgreSQL Database Schema (Supabase)
-- Full relational schema with foreign keys, constraints,
-- RLS policies, indexes, and 92 biomarker columns.
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. USERS TABLE
-- Stores patient demographic profiles, credentials, and cached AI summaries.
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email          TEXT UNIQUE NOT NULL,
    name           TEXT NOT NULL,
    gender         TEXT,                                     -- 'Male' | 'Female'
    dob            DATE,                                     -- YYYY-MM-DD
    ic_number      TEXT,                                     -- NRIC or Passport
    password_hash  TEXT NOT NULL,                            -- bcrypt hash
    status         TEXT NOT NULL DEFAULT 'active',           -- 'active' | 'inactive'
    health_summary TEXT,                                     -- Cached markdown AI health summary
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- ============================================================
-- 2. REPORTS TABLE
-- Stores raw OCR text, structured JSON payload, and verification status.
-- ============================================================
CREATE TABLE IF NOT EXISTS reports (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    filename         TEXT NOT NULL,
    upload_time      TIMESTAMPTZ NOT NULL DEFAULT now(),
    status           TEXT NOT NULL DEFAULT 'processing',     -- 'completed' | 'name_mismatch' | 'gender_mismatch' | 'age_mismatch' | 'sent'
    raw_text         TEXT,
    structured_data  JSONB,                                  -- Extracted JSON payload
    user_verified    INTEGER NOT NULL DEFAULT 0,              -- 0 = unverified, 1 = verified & sent
    file_path        TEXT
);

CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports (user_id);
CREATE INDEX IF NOT EXISTS idx_reports_upload_time ON reports (upload_time DESC);

-- ============================================================
-- 3. CHAT SESSIONS TABLE
-- Stores AI health consultation conversation threads.
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions (user_id);

-- ============================================================
-- 4. CHAT MESSAGES TABLE
-- Stores individual message turns within a consultation session.
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role        TEXT NOT NULL,                              -- 'user' | 'assistant'
    content     TEXT NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON chat_messages (session_id);

-- ============================================================
-- 5. STAGING MEDICAL RECORDS TABLE
-- 92-column normalized biomarker storage for longitudinal health analytics.
-- One verified report produces exactly one row in staging_medical_records.
-- ============================================================
CREATE TABLE IF NOT EXISTS staging_medical_records (
    staging_record_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id                   UUID NOT NULL UNIQUE REFERENCES reports(id) ON DELETE CASCADE,
    medid                       BIGINT,                     -- Normalized numeric patient identifier
    original_medid              TEXT,                       -- Raw extracted patient ID / MRN (from patient_id)
    labreference                TEXT,                       -- Normalized sample ID
    original_labreference       TEXT,                       -- Raw extracted specimen reference
    report_reference            TEXT,                       -- Accession / Episode number
    lab                         TEXT,                       -- Issuing clinic / hospital name (from hospital_name)
    collected                   DATE,                       -- Specimen collection date (YYYY-MM-DD)
    time                        TIME,                       -- Specimen collection time (HH:MM:SS)
    reported_time               TIME,                       -- Laboratory validation time (HH:MM:SS)
    gender                      TEXT,                       -- 'Male' | 'Female'

    -- 1. URINALYSIS
    urine_colour                TEXT,
    appearance                  TEXT,
    specific_gravity            NUMERIC,
    ph                          NUMERIC,
    proteins                    TEXT,
    glucose                     TEXT,
    bilirubin                   TEXT,
    ketones                     TEXT,
    blood                       TEXT,
    urobilinogen                TEXT,
    nitrites                    TEXT,
    wbc_pus_cells_hpf           TEXT,
    rbc                         TEXT,
    epithelial_cells_hpf        TEXT,
    casts                       TEXT,
    crystals                    TEXT,
    others                      TEXT,

    -- 2. COMPLETE BLOOD COUNT (CBC)
    hemoglobin_g_dl             NUMERIC,
    rbc_count_mil_ul            NUMERIC,
    hematocrit_pct              NUMERIC,
    mcv_fl                      NUMERIC,
    mch_pg                      NUMERIC,
    mchc_g_dl                   NUMERIC,
    rdw_cv_pct                  NUMERIC,
    rdw_sd_fl                   NUMERIC,
    wbc_cells_ul                NUMERIC,
    neutrophils_pct             NUMERIC,
    lymphocytes_pct             NUMERIC,
    eosinophils_pct             NUMERIC,
    monocytes_pct               NUMERIC,
    basophils_pct               NUMERIC,
    abs_neutrophils             NUMERIC,
    abs_lymphocytes             NUMERIC,
    abs_monocytes               NUMERIC,
    abs_eosinophils             NUMERIC,
    abs_basophils               NUMERIC,

    -- 3. PLATELET PROFILE
    platelet_count_x10_3_ul     NUMERIC,
    mpv_fl                      NUMERIC,
    platelet_rdw_pct            NUMERIC,
    pct_pct                     NUMERIC,
    p_lcr_pct                   NUMERIC,
    img_pct                     NUMERIC,
    imm_pct                     NUMERIC,
    iml_pct                     NUMERIC,
    lic_pct                     NUMERIC,

    -- 4. LIPID PROFILE
    total_cholesterol_mg_dl     NUMERIC,
    hdl_mg_dl                   NUMERIC,
    ldl_mg_dl                   NUMERIC,
    vldl_mg_dl                  NUMERIC,
    triglycerides_mg_dl         NUMERIC,
    non_hdl_mg_dl               NUMERIC,
    total_hdl_ratio             NUMERIC,
    ldl_hdl_ratio               NUMERIC,
    hdl_ldl_ratio               NUMERIC,

    -- 5. LIVER FUNCTION
    bilirubin_total_mg_dl       NUMERIC,
    bilirubin_direct_mg_dl      NUMERIC,
    bilirubin_indirect_mg_dl    NUMERIC,
    alp_u_l                     NUMERIC,
    alt_sgpt_u_l                NUMERIC,
    ast_sgot_u_l                NUMERIC,
    ggt_u_l                     NUMERIC,
    protein_total_g_dl          NUMERIC,
    albumin_g_dl                NUMERIC,
    globulin_g_dl               NUMERIC,
    a_g_ratio                   NUMERIC,

    -- 6. KIDNEY FUNCTION & ELECTROLYTES
    creatinine_mg_dl            NUMERIC,
    urea_mg_dl                  NUMERIC,
    bun_mg_dl                   NUMERIC,
    bun_creatinine_ratio        NUMERIC,
    sodium_mmol_l               NUMERIC,
    potassium_mmol_l            NUMERIC,
    chloride_mmol_l             NUMERIC,
    uric_acid_mg_dl             NUMERIC,
    egfr_ml_min_173m2           NUMERIC,

    -- 7. IRON PROFILE
    iron_ug_dl                  NUMERIC,
    uibc_ug_dl                  NUMERIC,
    tibc_ug_dl                  NUMERIC,
    transferrin_saturation_pct  NUMERIC,

    -- 8. DIABETIC / GLYCEMIC
    hba1c_pct                   NUMERIC,
    estimated_avg_glucose_mg_dl NUMERIC,
    hbf_pct                     NUMERIC,
    fasting_glucose_mg_dl       NUMERIC,
    postprandial_glucose_mg_dl  NUMERIC,
    fbs_mg_dl                   NUMERIC,
    plbs_mg_dl                  NUMERIC,

    -- 9. RENAL PROTEINURIA / ACR
    urine_albumin_mg_l          NUMERIC,
    urine_creatinine_mg_dl      NUMERIC,
    albumin_creatinine_ratio    NUMERIC,

    -- 10. MINERALS & BONE
    calcium_mg_dl               NUMERIC,
    phosphorus_mg_dl            NUMERIC,

    -- 11. THYROID PROFILE
    tt3_ng_dl                   NUMERIC,
    tt4_ug_dl                   NUMERIC,
    tsh_uiu_ml                  NUMERIC
);

CREATE INDEX IF NOT EXISTS idx_staging_report_id ON staging_medical_records (report_id);
CREATE INDEX IF NOT EXISTS idx_staging_medid_collected ON staging_medical_records (medid, collected);

-- ============================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE staging_medical_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to users" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to reports" ON reports FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to chat_sessions" ON chat_sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to chat_messages" ON chat_messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to staging_medical_records" ON staging_medical_records FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 7. EXPLICIT API ROLES GRANTS
-- Required for Supabase post-May 2026 schema visibility.
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_sessions TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_messages TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE staging_medical_records TO anon, authenticated, service_role;
