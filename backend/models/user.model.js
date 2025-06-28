const pool = require('../db');

async function findUserByEmail(email) {
  const res = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return res.rows[0];
}

async function createUser({ email, password, name, role, cedula, telefono }) {
  if (role) {
    await pool.query(
      'INSERT INTO users (email, password, name, role, cedula, telefono) VALUES ($1, $2, $3, $4, $5, $6)',
      [email, password, name, role, cedula, telefono]
    );
  } else {
    await pool.query(
      'INSERT INTO users (email, password, name, cedula, telefono) VALUES ($1, $2, $3, $4, $5)',
      [email, password, name, cedula, telefono]
    );
  }
}

module.exports = { findUserByEmail, createUser };
