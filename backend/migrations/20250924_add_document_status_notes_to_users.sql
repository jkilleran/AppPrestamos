-- Agrega columna JSONB para observaciones por documento (errores específicos)
ALTER TABLE users ADD COLUMN IF NOT EXISTS document_status_notes JSONB DEFAULT '{}'::jsonb;

-- Opcional: índice GIN si se quieren búsquedas por contenido de notas (no imprescindible)
-- CREATE INDEX IF NOT EXISTS idx_users_document_status_notes ON users USING GIN (document_status_notes);