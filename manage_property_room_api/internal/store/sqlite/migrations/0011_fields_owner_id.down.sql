DROP INDEX IF EXISTS idx_fields_owner_id;
ALTER TABLE fields DROP COLUMN owner_id;
