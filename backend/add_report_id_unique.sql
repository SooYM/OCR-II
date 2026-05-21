-- Migration: Fix staging_medical_records column types and constraints
-- Run this in the Supabase SQL Editor
-- =================================================================

-- 1. Fix epithelial_cells_hpf: should be TEXT to store ranges like "2-4", ">20"
--    The previous migration incorrectly changed it to NUMERIC, corrupting range values
ALTER TABLE staging_medical_records 
  ALTER COLUMN epithelial_cells_hpf TYPE TEXT 
  USING epithelial_cells_hpf::TEXT;

-- 2. Fix rbc: should be TEXT to handle potential range values in urinalysis
--    (e.g., "0-2", "occasional" etc. though current data shows integers)
ALTER TABLE staging_medical_records 
  ALTER COLUMN rbc TYPE TEXT
  USING rbc::TEXT;

-- 3. Remove duplicate report_id rows (keep only the latest one per report_id)
DELETE FROM staging_medical_records a
USING staging_medical_records b
WHERE a.staging_record_id < b.staging_record_id
  AND a.report_id IS NOT NULL
  AND a.report_id = b.report_id;

-- 4. Add UNIQUE constraint on report_id for proper upsert behavior
ALTER TABLE staging_medical_records
  ADD CONSTRAINT staging_medical_records_report_id_unique UNIQUE (report_id);
