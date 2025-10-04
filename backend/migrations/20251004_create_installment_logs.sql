-- Tabla de auditoría para transiciones de cuotas
CREATE TABLE IF NOT EXISTS loan_installment_logs (
  id SERIAL PRIMARY KEY,
  installment_id INT NOT NULL REFERENCES loan_installments(id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  admin_id INT REFERENCES users(id),
  paid_amount_before NUMERIC(14,2),
  paid_amount_after NUMERIC(14,2),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_installment_logs_installment ON loan_installment_logs(installment_id);
