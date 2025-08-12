const db = require('../db');

async function ensureTable() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS notifications (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      body TEXT,
      data JSONB,
      is_read BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
    CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);
  `);
}

async function createNotification(userId, { title, body, data }) {
  if (!userId || !title) return null;
  await ensureTable();
  const res = await db.query(
    'INSERT INTO notifications (user_id, title, body, data) VALUES ($1,$2,$3,$4) RETURNING *',
    [userId, title, body || null, data ? JSON.stringify(data) : null]
  );
  return res.rows[0];
}

async function listNotifications(userId, { limit = 50, offset = 0 } = {}) {
  await ensureTable();
  const res = await db.query(
    'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC, id DESC LIMIT $2 OFFSET $3',
    [userId, limit, offset]
  );
  return res.rows;
}

async function unreadCount(userId) {
  await ensureTable();
  const res = await db.query('SELECT COUNT(*)::int as c FROM notifications WHERE user_id = $1 AND is_read = FALSE', [userId]);
  return res.rows[0]?.c || 0;
}

async function markAsRead(userId, id) {
  await ensureTable();
  await db.query('UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND id = $2', [userId, id]);
}

async function markAllAsRead(userId) {
  await ensureTable();
  await db.query('UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE', [userId]);
}

module.exports = {
  createNotification,
  listNotifications,
  unreadCount,
  markAsRead,
  markAllAsRead,
};
