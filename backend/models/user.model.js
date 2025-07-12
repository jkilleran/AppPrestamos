const pool = require('../db');

async function findUserByEmail(email) {
  const res = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return res.rows[0];
}

async function createUser({ email, password, name, role, cedula, telefono, domicilio, salario }) {
  // Si no se envía role, usar 'cliente' por defecto
  if (!role) role = 'cliente';
  // Forzar valores por defecto si llegan vacíos o nulos
  domicilio = domicilio && domicilio.trim() ? domicilio : 'No especificado';
  salario = salario && salario !== '' ? Number(salario) : 0;
  await pool.query(
    'INSERT INTO users (email, password, name, role, cedula, telefono, domicilio, salario) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
    [email, password, name, role, cedula, telefono, domicilio, salario]
  );
}

module.exports = { findUserByEmail, createUser };
