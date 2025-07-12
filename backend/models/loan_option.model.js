const pool = require('../db');

// Modelo para opciones de préstamo (monto/rango, interés, plazo)
async function getAllLoanOptions() {
  const res = await pool.query('SELECT * FROM loan_options ORDER BY id ASC');
  return res.rows;
}

async function createLoanOption({ min_amount, max_amount, interest, months, categoria_minima }) {
  const res = await pool.query(
    `INSERT INTO loan_options (min_amount, max_amount, interest, months, categoria_minima)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [min_amount, max_amount, interest, months, categoria_minima || 'Hierro']
  );
  return res.rows[0];
}

async function updateLoanOption(id, { min_amount, max_amount, interest, months, categoria_minima }) {
  const res = await pool.query(
    `UPDATE loan_options SET min_amount=$1, max_amount=$2, interest=$3, months=$4, categoria_minima=$5 WHERE id=$6 RETURNING *`,
    [min_amount, max_amount, interest, months, categoria_minima || 'Hierro', id]
  );
  return res.rows[0];
}

async function deleteLoanOption(id) {
  await pool.query('DELETE FROM loan_options WHERE id=$1', [id]);
  return { success: true };
}

module.exports = { getAllLoanOptions, createLoanOption, updateLoanOption, deleteLoanOption };
