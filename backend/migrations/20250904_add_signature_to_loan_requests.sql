-- Adds electronic signature fields to loan_requests
ALTER TABLE loan_requests
  ADD COLUMN IF NOT EXISTS signature_data TEXT,
  ADD COLUMN IF NOT EXISTS signed_at TIMESTAMP;
