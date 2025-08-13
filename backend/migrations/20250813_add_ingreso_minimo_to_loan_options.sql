-- Adds ingreso_minimo column to loan_options
ALTER TABLE loan_options
ADD COLUMN IF NOT EXISTS ingreso_minimo NUMERIC(12,2);
