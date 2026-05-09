-- Track who created each group so the list can be scoped per role:
-- admin sees all; owner sees groups created by their supervisors (or self);
-- supervisor sees only groups they created.
ALTER TABLE groups ADD COLUMN created_by TEXT;
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by);
