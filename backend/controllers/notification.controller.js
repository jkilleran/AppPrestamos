const { listNotifications, markAsRead, markAllAsRead, unreadCount } = require('../models/notification.model');

async function getMyNotifications(req, res) {
  try {
    const userId = req.user.id;
    const items = await listNotifications(userId, { limit: 50, offset: 0 });
    const unread = await unreadCount(userId);
    res.json({ items, unread });
  } catch (e) {
    res.status(500).json({ error: 'No se pudieron obtener notificaciones', detail: e.message });
  }
}

async function markOneRead(req, res) {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    await markAsRead(userId, id);
    const unread = await unreadCount(userId);
    res.json({ ok: true, unread });
  } catch (e) {
    res.status(500).json({ error: 'No se pudo marcar como leída', detail: e.message });
  }
}

async function markAllRead(req, res) {
  try {
    const userId = req.user.id;
    await markAllAsRead(userId);
    res.json({ ok: true, unread: 0 });
  } catch (e) {
    res.status(500).json({ error: 'No se pudieron marcar todas como leídas', detail: e.message });
  }
}

module.exports = { getMyNotifications, markOneRead, markAllRead };
