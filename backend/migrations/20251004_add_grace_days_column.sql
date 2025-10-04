-- Agrega columna grace_days a loan_installments si no existe.
ALTER TABLE loan_installments
  ADD COLUMN IF NOT EXISTS grace_days INTEGER DEFAULT 0;

-- Índice opcional para consultas de atraso que usan due_date + grace_days
CREATE INDEX IF NOT EXISTS idx_loan_installments_due_grace
  ON loan_installments (due_date, grace_days);