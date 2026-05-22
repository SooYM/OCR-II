-- Transaction to rename sample_id and swap data on Supabase
BEGIN;

-- 1. Add temporary backup columns
ALTER TABLE staging_medical_records ADD COLUMN temp_old_labreference TEXT;
ALTER TABLE staging_medical_records ADD COLUMN temp_old_sample_id TEXT;

-- 2. Copy current values to backup columns
UPDATE staging_medical_records SET
    temp_old_labreference = labreference,
    temp_old_sample_id = sample_id;

-- 3. Rename sample_id to report_reference
ALTER TABLE staging_medical_records RENAME COLUMN sample_id TO report_reference;

-- Ensure report_reference is TEXT
ALTER TABLE staging_medical_records ALTER COLUMN report_reference TYPE TEXT USING report_reference::TEXT;

-- 4. Swap the data using the backups
UPDATE staging_medical_records SET
    labreference = temp_old_sample_id,
    report_reference = temp_old_labreference;

-- 5. Drop the temporary columns
ALTER TABLE staging_medical_records DROP COLUMN temp_old_labreference;
ALTER TABLE staging_medical_records DROP COLUMN temp_old_sample_id;

COMMIT;
