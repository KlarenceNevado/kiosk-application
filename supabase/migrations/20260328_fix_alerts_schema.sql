-- Migration: Fix alerts table schema and RLS policy
-- Issue: Alerts push fails with RLS 42501 because:
-- 1. Missing UPDATE policy on alerts table
-- 2. Missing is_deleted, is_active, updated_at columns

-- Add missing columns
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Add missing UPDATE policy
DO $$
BEGIN
    DROP POLICY IF EXISTS "Allow Anon Update Alerts" ON alerts;
EXCEPTION WHEN others THEN NULL;
END $$;

CREATE POLICY "Allow Anon Update Alerts" ON alerts
    FOR UPDATE USING (id IS NOT NULL) WITH CHECK (id IS NOT NULL);
