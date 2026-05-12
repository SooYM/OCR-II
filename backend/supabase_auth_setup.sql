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
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast email lookups during login
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- 2. Add user_id column to existing reports table (skip if already exists)
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

-- 3. Enable Row Level Security on users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: allow the API (service role / anon key) to manage users
-- Since we use server-side auth (not Supabase Auth), allow all via API key
CREATE POLICY IF NOT EXISTS "Allow all access to users"
    ON users FOR ALL
    USING (true)
    WITH CHECK (true);

-- 4. Ensure reports table also has RLS policy for API access
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Allow all access to reports"
    ON reports FOR ALL
    USING (true)
    WITH CHECK (true);

-- ============================================================
-- Done! Your Supabase tables are ready for MedScan auth.
-- ============================================================
