-- Stores one (latest) document per (user_id, doc_type). Overwrite semantics.

CREATE TABLE IF NOT EXISTS user_documents (
  id BIGSERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL,
  content_type TEXT NOT NULL,
  original_filename TEXT,
  byte_size INTEGER NOT NULL,
  data BYTEA NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, doc_type)
);

CREATE INDEX IF NOT EXISTS user_documents_user_id_idx ON user_documents(user_id);
CREATE INDEX IF NOT EXISTS user_documents_doc_type_idx ON user_documents(doc_type);
