-- Add a dedicated signature_status column so the loan status and signature status are not conflated
-- Values: 'no_firmada' | 'firmada' | (optional future: 'revocada')

ALTER TABLE loan_requests
ADD COLUMN IF NOT EXISTS signature_status VARCHAR(20) NOT NULL DEFAULT 'no_firmada';

-- Backfill: mark as firmada when there's image or timestamp
UPDATE loan_requests
SET signature_status = 'firmada'
WHERE signature_status IS DISTINCT FROM 'firmada'
  AND (
    (signature_data IS NOT NULL AND length(trim(signature_data)) > 0)
    OR signed_at IS NOT NULL
  );

-- Optional: small index to filter admin lists by signed
CREATE INDEX IF NOT EXISTS idx_loan_requests_signature_status ON loan_requests(signature_status);
