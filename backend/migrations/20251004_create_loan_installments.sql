-- Create loan_installments table to manage cuotas / installments for approved loans
-- This table is generated automatically when a loan_request is approved (status = 'aprobado').
-- We avoid regenerating if rows already exist for the loan_request_id.

CREATE TABLE IF NOT EXISTS loan_installments (
  id SERIAL PRIMARY KEY,
  loan_request_id INTEGER NOT NULL REFERENCES loan_requests(id) ON DELETE CASCADE,
  installment_number INTEGER NOT NULL, -- 1..N
  due_date DATE NOT NULL,
  capital NUMERIC(14,2) NOT NULL DEFAULT 0, -- portion of principal
  interest NUMERIC(14,2) NOT NULL DEFAULT 0, -- portion of interest
  total_due NUMERIC(14,2) NOT NULL, -- capital + interest scheduled
  paid_amount NUMERIC(14,2) NOT NULL DEFAULT 0, -- actual sum paid (may allow partials future)
  paid_at TIMESTAMP NULL, -- when fully paid
  status VARCHAR(24) NOT NULL DEFAULT 'pendiente', -- pendiente | reportado | pagado | atrasado | rechazado
  reported_at TIMESTAMP NULL, -- when user uploaded receipt
  receipt_original_name TEXT NULL,
  receipt_meta JSONB, -- arbitrary metadata (user id, email, comentario, email send result, etc.)
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(loan_request_id, installment_number)
);

CREATE INDEX IF NOT EXISTS idx_loan_installments_loan ON loan_installments(loan_request_id);
CREATE INDEX IF NOT EXISTS idx_loan_installments_status ON loan_installments(status);

-- Trigger to auto update updated_at
CREATE OR REPLACE FUNCTION trg_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_updated_at_loan_installments ON loan_installments;
CREATE TRIGGER trg_touch_updated_at_loan_installments
BEFORE UPDATE ON loan_installments
FOR EACH ROW EXECUTE FUNCTION trg_touch_updated_at();
