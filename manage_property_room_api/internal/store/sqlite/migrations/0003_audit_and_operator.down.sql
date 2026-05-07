-- Revert operator role and audit_events table
DROP TABLE IF EXISTS audit_events;

-- Recreate users table without operator role
CREATE TABLE users_old (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  initials TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin','cleaning','maintenance')),
  must_change_password INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
INSERT INTO users_old SELECT
  id, email, password_hash, name, initials, role,
  must_change_password, created_at, updated_at
FROM users;
DROP TABLE users;
ALTER TABLE users_old RENAME TO users;
