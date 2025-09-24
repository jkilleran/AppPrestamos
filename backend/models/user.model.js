const pool = require('../db');

async function findUserByEmail(email) {
  const res = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return res.rows[0];
}

async function createUser({ email, password, name, role, cedula, telefono, domicilio, salario, foto, categoria }) {
  const { isValidCedula, normalizeCedula } = require('../utils/validation');
  // Rol por defecto
  if (!role) role = 'cliente';
  // Normalizaciones
  domicilio = domicilio && domicilio.trim() ? domicilio : 'No especificado';
  salario = salario && salario !== '' ? Number(salario) : 0;
  categoria = categoria || 'Hierro';
  // Validar cédula
  const cedulaNormalized = normalizeCedula(cedula);
  if (!isValidCedula(cedulaNormalized)) {
    throw new Error('Cédula inválida (debe contener 11 dígitos)');
  }
  // Verificar unicidad manual (además del índice único opcional)
  const dupe = await pool.query('SELECT 1 FROM users WHERE cedula = $1', [cedulaNormalized]);
  if (dupe.rowCount) {
    throw new Error('La cédula ya está registrada');
  }
  await pool.query(
    'INSERT INTO users (email, password, name, role, cedula, telefono, domicilio, salario, foto, categoria, prestamos_aprobados) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)',
    [email, password, name, role, cedulaNormalized, telefono, domicilio, salario, foto, categoria, 0]
  );
}

async function updateUserPhoto(userId, foto) {
  await pool.query('UPDATE users SET foto = $1 WHERE id = $2', [foto, userId]);
}

async function findUserById(id) {
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
  return result.rows[0];
}

async function findUserByCedula(cedula) {
  const result = await pool.query('SELECT * FROM users WHERE cedula = $1', [cedula]);
  return result.rows[0];
}

async function incrementPrestamosAprobadosAndUpdateCategoria(userId) {
  // Obtiene el número actual, suma 1, y actualiza la categoría
  const userRes = await pool.query('SELECT prestamos_aprobados FROM users WHERE id = $1', [userId]);
  let prestamos = (userRes.rows[0]?.prestamos_aprobados || 0) + 1;
  // Cada préstamo aprobado sube una categoría
  const categorias = ['Hierro', 'Plata', 'Oro', 'Platino', 'Diamante', 'Esmeralda'];
  let categoria = categorias[Math.min(prestamos, categorias.length - 1)];
  await pool.query('UPDATE users SET prestamos_aprobados = $1, categoria = $2 WHERE id = $3', [prestamos, categoria, userId]);
  return { prestamos, categoria };
}

async function listAdmins() {
  const res = await pool.query("SELECT id, name, email FROM users WHERE role = 'admin'");
  return res.rows;
}

module.exports = { findUserByEmail, createUser, updateUserPhoto, findUserById, findUserByCedula, incrementPrestamosAprobadosAndUpdateCategoria, listAdmins };
