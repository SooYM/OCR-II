-- Run this script in the Supabase SQL Editor (Dashboard > SQL Editor)
ALTER TABLE users ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE users ADD COLUMN IF NOT EXISTS dob TEXT;
