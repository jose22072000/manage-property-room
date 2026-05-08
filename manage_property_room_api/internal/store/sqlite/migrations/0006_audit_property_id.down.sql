-- Down: remove property_id index (column drop not supported in SQLite < 3.35, skip)
DROP INDEX IF EXISTS idx_audit_property;
