CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed optional default email (replace with actual desired or leave commented)
-- INSERT INTO settings(key, value) VALUES('document_target_email','destino@example.com') ON CONFLICT (key) DO NOTHING;
