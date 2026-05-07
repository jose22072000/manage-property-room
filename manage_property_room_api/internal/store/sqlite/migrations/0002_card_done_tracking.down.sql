-- SQLite does not support DROP COLUMN in older versions; migration is irreversible.
-- No-op down migration.
SELECT 1;
