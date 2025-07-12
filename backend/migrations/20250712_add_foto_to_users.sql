-- Migración para agregar columna de foto de perfil a la tabla users
ALTER TABLE users ADD COLUMN foto VARCHAR(255);
