DROP TABLE IF EXISTS group_properties;
DROP TABLE IF EXISTS group_users;
DROP TABLE IF EXISTS groups;

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
  id, email, password_hash, name, initials,
  CASE WHEN role IN ('owner','supervisor') THEN 'operator' ELSE role END,
  must_change_password, created_at, updated_at
FROM users;
DROP TABLE users;
ALTER TABLE users_new RENAME TO users;
