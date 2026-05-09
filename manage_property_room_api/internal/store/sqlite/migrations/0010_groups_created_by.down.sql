DROP INDEX IF EXISTS idx_groups_created_by;
ALTER TABLE groups DROP COLUMN created_by;
