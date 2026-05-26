-- Run this script in the Supabase SQL Editor (Dashboard > SQL Editor)
ALTER TABLE users DROP COLUMN IF EXISTS dob;
ALTER TABLE users ADD COLUMN dob DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ic_number TEXT;
ALTER TABLE users DROP COLUMN IF EXISTS age;
