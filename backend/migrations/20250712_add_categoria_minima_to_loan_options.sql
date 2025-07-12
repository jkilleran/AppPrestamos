-- Agrega la columna categoria_minima a la tabla loan_options
ALTER TABLE loan_options ADD COLUMN categoria_minima VARCHAR(20) DEFAULT 'Hierro';
