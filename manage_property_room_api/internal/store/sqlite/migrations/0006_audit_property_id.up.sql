-- Add property_id to audit_events for owner-scoped notifications
ALTER TABLE audit_events ADD COLUMN property_id TEXT;
CREATE INDEX IF NOT EXISTS idx_audit_property ON audit_events(property_id);
