const pool = require('../db');

async function findUserByEmail(email) {
  const res = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return res.rows[0];
}

async function createUser({ email, password, name, role, cedula, telefono, domicilio, salario, foto, categoria }) {
  // Si no se envía role, usar 'cliente' por defecto
  if (!role) role = 'cliente';
  // Forzar valores por defecto si llegan vacíos o nulos
  domicilio = domicilio && domicilio.trim() ? domicilio : 'No especificado';
  salario = salario && salario !== '' ? Number(salario) : 0;
  categoria = categoria || 'Hierro';
  await pool.query(
    'INSERT INTO users (email, password, name, role, cedula, telefono, domicilio, salario, foto, categoria) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
    [email, password, name, role, cedula, telefono, domicilio, salario, foto, categoria]
  );
}

async function updateUserPhoto(userId, foto) {
  await pool.query('UPDATE users SET foto = $1 WHERE id = $2', [foto, userId]);
}

async function findUserById(id) {
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
  return result.rows[0];
}

module.exports = { findUserByEmail, createUser, updateUserPhoto, findUserById };
