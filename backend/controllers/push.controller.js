const { upsertToken, removeToken, sendPushToUser } = require('../services/push');

async function registerToken(req, res) {
  try {
    const userId = req.user.id;
    const { token, platform } = req.body;
    if (!token) return res.status(400).json({ error: 'token requerido' });
    await upsertToken({ userId, token, platform });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'No se pudo registrar token', detail: e.message });
  }
}

async function unregisterToken(req, res) {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'token requerido' });
    await removeToken(token);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'No se pudo eliminar token', detail: e.message });
  }
}

async function testPush(req, res) {
  try {
    const userId = req.user.id;
    const { title = 'Test', body = 'Notificación de prueba', data = {} } = req.body || {};
    await sendPushToUser({ userId, title, body, data });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'No se pudo enviar test', detail: e.message });
  }
}

module.exports = { registerToken, unregisterToken, testPush };
