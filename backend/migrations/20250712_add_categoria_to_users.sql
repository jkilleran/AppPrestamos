-- Agrega la columna categoria al usuario, por defecto 'Hierro'
ALTER TABLE users ADD COLUMN categoria VARCHAR(20) DEFAULT 'Hierro';
