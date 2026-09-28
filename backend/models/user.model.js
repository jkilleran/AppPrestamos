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
  // One atomic UPDATE avoids lost increments when two different loans are
  // approved concurrently for the same user.
  const result = await pool.query(
    `UPDATE users
        SET prestamos_aprobados = COALESCE(prestamos_aprobados, 0) + 1,
            categoria = CASE LEAST(COALESCE(prestamos_aprobados, 0) + 1, 5)
              WHEN 0 THEN 'Hierro'
              WHEN 1 THEN 'Plata'
              WHEN 2 THEN 'Oro'
              WHEN 3 THEN 'Platino'
              WHEN 4 THEN 'Diamante'
              ELSE 'Esmeralda'
            END
      WHERE id = $1
      RETURNING prestamos_aprobados, categoria`,
    [userId],
  );
  if (!result.rows.length) throw new Error('Usuario no encontrado');
  return {
    prestamos: result.rows[0].prestamos_aprobados,
    categoria: result.rows[0].categoria,
  };
}

async function listAdmins() {
  const res = await pool.query("SELECT id, name, email FROM users WHERE role = 'admin'");
  return res.rows;
}

module.exports = { findUserByEmail, createUser, updateUserPhoto, findUserById, findUserByCedula, incrementPrestamosAprobadosAndUpdateCategoria, listAdmins };
