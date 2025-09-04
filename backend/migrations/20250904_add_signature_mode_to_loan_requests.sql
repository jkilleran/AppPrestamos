-- Agrega columna para indicar el modo de la firma (drawn / typed)
ALTER TABLE loan_requests
  ADD COLUMN IF NOT EXISTS signature_mode VARCHAR(16);
