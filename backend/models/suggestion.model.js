const pool = require('../db');

async function createSuggestion({ user_id, user_name, user_phone, title, content }) {
  const res = await pool.query(
    `INSERT INTO suggestions (user_id, user_name, user_phone, title, content)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [user_id, user_name, user_phone, title, content]
  );
  return res.rows[0];
}

async function listSuggestionsByUser(user_id) {
  const res = await pool.query(
    `SELECT * FROM suggestions WHERE user_id = $1 ORDER BY created_at DESC`,
    [user_id]
  );
  return res.rows;
}

async function listAllSuggestions() {
  const res = await pool.query(
    `SELECT s.*, u.email AS user_email
     FROM suggestions s
     LEFT JOIN users u ON u.id = s.user_id
     ORDER BY s.created_at DESC`
  );
  return res.rows;
}

async function updateSuggestionStatus(id, status) {
  const res = await pool.query(
    `UPDATE suggestions SET status = $1 WHERE id = $2 RETURNING *`,
    [status, id]
  );
  return res.rows[0];
}

async function deleteSuggestion(id) {
  await pool.query(`DELETE FROM suggestions WHERE id = $1`, [id]);
}

module.exports = {
  createSuggestion,
  listSuggestionsByUser,
  listAllSuggestions,
  updateSuggestionStatus,
  deleteSuggestion,
};
