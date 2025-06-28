CREATE TABLE IF NOT EXISTS loan_options (
  id SERIAL PRIMARY KEY,
  min_amount NUMERIC(12,2) NOT NULL,
  max_amount NUMERIC(12,2) NOT NULL,
  interest NUMERIC(5,2) NOT NULL,
  months INTEGER NOT NULL
);
