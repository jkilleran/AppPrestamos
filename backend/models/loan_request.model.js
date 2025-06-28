const pool = require('../db');

async function createLoanRequest({ userId, userName, amount, months, interest, purpose }) {
  const res = await pool.query(
    `INSERT INTO loan_requests (user_id, user_name, amount, months, interest, purpose)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [userId, userName, amount, months, interest, purpose]
  );
  return res.rows[0];
}

async function getAllLoanRequests() {
  const res = await pool.query('SELECT * FROM loan_requests ORDER BY created_at DESC');
  return res.rows;
}

async function updateLoanRequestStatus(id, status) {
  const res = await pool.query('UPDATE loan_requests SET status = $1 WHERE id = $2 RETURNING *', [status, id]);
  return res.rows[0];
}

module.exports = { createLoanRequest, getAllLoanRequests, updateLoanRequestStatus };
