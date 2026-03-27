-- Supabase Migration: Add Missing Patient Columns
-- This script aligns the cloud 'patients' table with the local SQLite schema.

-- 1. Add 'is_active' column (defaults to true)
ALTER TABLE patients ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 2. Add 'is_deleted' column (defaults to false)
ALTER TABLE patients ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;

-- 3. Add 'relation' column (for family dependents mapping)
ALTER TABLE patients ADD COLUMN IF NOT EXISTS relation TEXT;

-- 4. Ensure 'date_of_birth' is of type DATE (for proper indexing and range queries)
-- Note: If this column already exists as TEXT, casting might be needed.
-- ALTER TABLE patients ALTER COLUMN date_of_birth TYPE DATE USING date_of_birth::DATE;

-- COMMENT ON COLUMNS
COMMENT ON COLUMN patients.is_active IS 'Status indicating if the patient account is currently active.';
COMMENT ON COLUMN patients.is_deleted IS 'Soft-delete flag for data retention policies.';
COMMENT ON COLUMN patients.relation IS 'Relationship to parent (for dependent accounts).';
