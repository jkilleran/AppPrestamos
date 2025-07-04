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
  const res = await pool.query(`
    SELECT lr.*, u.name as user_name, u.email as user_email, u.cedula as user_cedula, u.telefono as user_telefono, u.role as user_role
    FROM loan_requests lr
    JOIN users u ON lr.user_id = u.id
    ORDER BY lr.created_at DESC
  `);
  return res.rows;
}

async function updateLoanRequestStatus(id, status) {
  const res = await pool.query('UPDATE loan_requests SET status = $1 WHERE id = $2 RETURNING *', [status, id]);
  return res.rows[0];
}

async function getLoanRequestsByUser(userId) {
  const res = await pool.query(`
    SELECT lr.*, u.name as user_name, u.email as user_email, u.cedula as user_cedula, u.telefono as user_telefono, u.role as user_role
    FROM loan_requests lr
    JOIN users u ON lr.user_id = u.id
    WHERE lr.user_id = $1
    ORDER BY lr.created_at DESC
  `, [userId]);
  return res.rows;
}

module.exports = { createLoanRequest, getAllLoanRequests, updateLoanRequestStatus, getLoanRequestsByUser };
