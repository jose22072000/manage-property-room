-- Add operator role to users table constraint
-- SQLite doesn't support ALTER TABLE to modify CHECK constraints, so we
-- recreate the table using a temporary rename approach.
CREATE TABLE users_new (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  initials TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin','operator','cleaning','maintenance')),
  must_change_password INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
INSERT INTO users_new SELECT
  id, email, password_hash, name, initials, role,
  must_change_password, created_at, updated_at
FROM users;
DROP TABLE users;
ALTER TABLE users_new RENAME TO users;

-- Audit events log
CREATE TABLE IF NOT EXISTS audit_events (
  id         TEXT PRIMARY KEY,
  actor_id   TEXT NOT NULL,
  actor_name TEXT NOT NULL,
  action     TEXT NOT NULL,
  entity     TEXT NOT NULL,
  entity_id  TEXT NOT NULL,
  detail     TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_events(entity, entity_id);
