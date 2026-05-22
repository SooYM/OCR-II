-- Migration: support lab number (sample_id) duplicate checks and facility of the lab (lab)
-- Run this in the Supabase SQL Editor
-- =================================================================

-- 1. Alter sample_id in staging_medical_records to TEXT to support alphanumeric lab numbers
ALTER TABLE staging_medical_records 
  ALTER COLUMN sample_id TYPE TEXT 
  USING sample_id::TEXT;

-- 2. Add lab column to staging_medical_records to store the facility of the lab
ALTER TABLE staging_medical_records 
  ADD COLUMN IF NOT EXISTS lab TEXT;
