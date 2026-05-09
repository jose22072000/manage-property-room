-- Add actor IP address to audit events
ALTER TABLE audit_events ADD COLUMN actor_ip TEXT NOT NULL DEFAULT '';
