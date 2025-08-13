const pool = require('../db');

// Modelo para opciones de préstamo (monto/rango, interés, plazo)
async function getAllLoanOptions({ salarioMinimo } = {}) {
  // If salarioMinimo provided, only return options where ingreso_minimo is null or <= salarioMinimo
  if (salarioMinimo != null) {
    const res = await pool.query(
      'SELECT * FROM loan_options WHERE ingreso_minimo IS NULL OR ingreso_minimo <= $1 ORDER BY id ASC',
      [salarioMinimo]
    );
    return res.rows;
  }
  const res = await pool.query('SELECT * FROM loan_options ORDER BY id ASC');
  return res.rows;
}

async function createLoanOption({ min_amount, max_amount, interest, months, categoria_minima, ingreso_minimo }) {
  const res = await pool.query(
    `INSERT INTO loan_options (min_amount, max_amount, interest, months, categoria_minima, ingreso_minimo)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [min_amount, max_amount, interest, months, categoria_minima || 'Hierro', ingreso_minimo]
  );
  return res.rows[0];
}

async function updateLoanOption(id, { min_amount, max_amount, interest, months, categoria_minima, ingreso_minimo }) {
  const res = await pool.query(
    `UPDATE loan_options SET min_amount=$1, max_amount=$2, interest=$3, months=$4, categoria_minima=$5, ingreso_minimo=$6 WHERE id=$7 RETURNING *`,
    [min_amount, max_amount, interest, months, categoria_minima || 'Hierro', ingreso_minimo, id]
  );
  return res.rows[0];
}

async function deleteLoanOption(id) {
  await pool.query('DELETE FROM loan_options WHERE id=$1', [id]);
  return { success: true };
}

module.exports = { getAllLoanOptions, createLoanOption, updateLoanOption, deleteLoanOption };
