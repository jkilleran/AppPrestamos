const pool = require('../db');

// Modelo para opciones de préstamo (monto/rango, interés, plazo)
async function getAllLoanOptions() {
  const res = await pool.query('SELECT * FROM loan_options ORDER BY id ASC');
  return res.rows;
}

async function createLoanOption({ min_amount, max_amount, interest, months }) {
  const res = await pool.query(
    `INSERT INTO loan_options (min_amount, max_amount, interest, months)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [min_amount, max_amount, interest, months]
  );
  return res.rows[0];
}

async function updateLoanOption(id, { min_amount, max_amount, interest, months }) {
  const res = await pool.query(
    `UPDATE loan_options SET min_amount=$1, max_amount=$2, interest=$3, months=$4 WHERE id=$5 RETURNING *`,
    [min_amount, max_amount, interest, months, id]
  );
  return res.rows[0];
}

async function deleteLoanOption(id) {
  await pool.query('DELETE FROM loan_options WHERE id=$1', [id]);
  return { success: true };
}

module.exports = { getAllLoanOptions, createLoanOption, updateLoanOption, deleteLoanOption };
