-- Migration: create email_outbox table
CREATE TABLE IF NOT EXISTS email_outbox (
  id SERIAL PRIMARY KEY,
  target TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT,
  attachments JSONB,
  status TEXT NOT NULL DEFAULT 'pending', -- pending | sent | failed
  attempts INT NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS email_outbox_status_idx ON email_outbox(status);
