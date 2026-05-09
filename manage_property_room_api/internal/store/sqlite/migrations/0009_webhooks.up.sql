-- Outbound webhooks: configurable HTTP callbacks fired on card events.
CREATE TABLE IF NOT EXISTS webhooks (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  url         TEXT NOT NULL,
  secret      TEXT NOT NULL,
  events      TEXT NOT NULL,            -- JSON array of event names
  property_id TEXT,                     -- nullable: scope to a single property
  active      INTEGER NOT NULL DEFAULT 1,
  created_by  TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_webhooks_property ON webhooks(property_id);
CREATE INDEX IF NOT EXISTS idx_webhooks_active   ON webhooks(active);

-- Audit log of dispatch attempts (for debugging and retry visibility).
CREATE TABLE IF NOT EXISTS webhook_deliveries (
  id         TEXT PRIMARY KEY,
  webhook_id TEXT NOT NULL,
  event      TEXT NOT NULL,
  payload    TEXT NOT NULL,
  status     TEXT NOT NULL,             -- pending|success|failed
  http_code  INTEGER NOT NULL DEFAULT 0,
  attempts   INTEGER NOT NULL DEFAULT 0,
  last_error TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_deliveries_webhook ON webhook_deliveries(webhook_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_created ON webhook_deliveries(created_at DESC);

-- Inbound webhooks: external systems POST here to create cards.
CREATE TABLE IF NOT EXISTS inbound_hooks (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  token       TEXT NOT NULL UNIQUE,
  secret      TEXT NOT NULL DEFAULT '', -- optional HMAC verification
  property_id TEXT NOT NULL,
  column_id   TEXT NOT NULL,
  active      INTEGER NOT NULL DEFAULT 1,
  created_by  TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_inbound_token ON inbound_hooks(token);
