-- Add owner and supervisor roles to users table constraint
-- SQLite doesn't support ALTER TABLE to modify CHECK constraints, so we recreate.
CREATE TABLE users_new (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  initials TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin','operator','cleaning','maintenance','owner','supervisor')),
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

-- Groups
CREATE TABLE IF NOT EXISTS groups (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Group → user memberships
CREATE TABLE IF NOT EXISTS group_users (
  group_id   TEXT NOT NULL,
  user_id    TEXT NOT NULL,
  PRIMARY KEY (group_id, user_id),
  FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE
);

-- Group → property assignments
CREATE TABLE IF NOT EXISTS group_properties (
  group_id    TEXT NOT NULL,
  property_id TEXT NOT NULL,
  PRIMARY KEY (group_id, property_id),
  FOREIGN KEY (group_id)    REFERENCES groups(id)     ON DELETE CASCADE,
  FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE
);
