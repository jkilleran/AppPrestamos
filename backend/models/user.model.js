const pool = require('../db');

async function findUserByEmail(email) {
  const res = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return res.rows[0];
}

async function createUser({ email, password, name, role }) {
  if (role) {
    await pool.query(
      'INSERT INTO users (email, password, name, role) VALUES ($1, $2, $3, $4)',
      [email, password, name, role]
    );
  } else {
    await pool.query(
      'INSERT INTO users (email, password, name) VALUES ($1, $2, $3)',
      [email, password, name]
    );
  }
}

module.exports = { findUserByEmail, createUser };
