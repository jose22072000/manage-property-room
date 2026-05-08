-- Add created_by to users (who created this user)
ALTER TABLE users ADD COLUMN created_by TEXT;

-- Add owner to properties
ALTER TABLE properties ADD COLUMN owner_user_id TEXT;

-- Property ↔ supervisor assignments
CREATE TABLE IF NOT EXISTS property_supervisors (
  property_id   TEXT NOT NULL,
  supervisor_id TEXT NOT NULL,
  PRIMARY KEY (property_id, supervisor_id),
  FOREIGN KEY (property_id)   REFERENCES properties(id) ON DELETE CASCADE,
  FOREIGN KEY (supervisor_id) REFERENCES users(id)      ON DELETE CASCADE
);
