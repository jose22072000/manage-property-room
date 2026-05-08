DROP TABLE IF EXISTS property_supervisors;
ALTER TABLE properties DROP COLUMN owner_user_id;
ALTER TABLE users DROP COLUMN created_by;
