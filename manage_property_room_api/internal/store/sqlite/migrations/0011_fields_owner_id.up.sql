-- Per-owner field scoping. NULL owner_id == legacy/global (admin-only).
ALTER TABLE fields ADD COLUMN owner_id TEXT;
CREATE INDEX IF NOT EXISTS idx_fields_owner_id ON fields(owner_id);

-- Migrate existing field defs to the first seeded owner so demo data
-- continues to be visible to that owner and their supervisors/workers.
UPDATE fields SET owner_id = (
  SELECT id FROM users WHERE role = 'owner' ORDER BY created_at LIMIT 1
) WHERE owner_id IS NULL;
