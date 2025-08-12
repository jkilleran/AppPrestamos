const fetch = require('node-fetch');
const db = require('../db');

const FCM_ENDPOINT = 'https://fcm.googleapis.com/fcm/send'; // Legacy HTTP API

async function ensureTable() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS device_tokens (
        token TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        platform TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);
  } catch (e) {
    console.error('[push] No se pudo asegurar la tabla device_tokens:', e.message);
  }
}

async function upsertToken({ userId, token, platform }) {
  if (!userId || !token) return;
  await ensureTable();
  await db.query(
    `INSERT INTO device_tokens (token, user_id, platform, created_at, updated_at)
     VALUES ($1,$2,$3,NOW(),NOW())
     ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW()`,
    [token, userId, platform || null]
  );
}

async function removeToken(token) {
  if (!token) return;
  await ensureTable();
  await db.query('DELETE FROM device_tokens WHERE token = $1', [token]);
}

async function listTokensByUser(userId) {
  await ensureTable();
  const res = await db.query('SELECT token FROM device_tokens WHERE user_id = $1', [userId]);
  return res.rows.map(r => r.token);
}

async function sendPushRaw({ token, title, body, data }) {
  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey) {
    console.warn('[push] FCM_SERVER_KEY no configurado; omitiendo push');
    return { skipped: true };
  }
  const payload = {
    to: token,
    notification: { title, body },
    data: data || {},
  };
  const resp = await fetch(FCM_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'key=' + serverKey,
    },
    body: JSON.stringify(payload),
  });
  const txt = await resp.text();
  if (!resp.ok) {
    console.warn('[push] Error FCM', resp.status, txt);
  }
  return { status: resp.status, body: txt };
}

async function sendPushToUser({ userId, title, body, data }) {
  const tokens = await listTokensByUser(userId);
  for (const t of tokens) {
    try {
      await sendPushRaw({ token: t, title, body, data });
    } catch (e) {
      console.warn('[push] fallo token', t, e.message);
    }
  }
}

module.exports = {
  upsertToken,
  removeToken,
  listTokensByUser,
  sendPushToUser,
  sendPushRaw,
};
