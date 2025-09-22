const suggestionModel = require('../models/suggestion.model');
const { listAdmins } = require('../models/user.model');
const { createNotification } = require('../models/notification.model');
const { sendPushToUser } = require('../services/push');

async function createSuggestionController(req, res) {
  try {
    const user = req.user; // from auth middleware
    const { title, content } = req.body;
    if (!title || !content) {
      return res.status(400).json({ message: 'Título y contenido son requeridos' });
    }
    const created = await suggestionModel.createSuggestion({
      user_id: user.id,
      user_name: user.name || 'Usuario',
      user_phone: user.telefono || null,
      title: title.toString().trim(),
      content: content.toString().trim(),
    });
    // Notificar a todos los administradores
    try {
      const admins = await listAdmins();
      const notifTitle = 'Nueva sugerencia';
      const notifBody = `${user.name || 'Usuario'}: ${title.toString().trim()}`;
      const data = { type: 'suggestion_new', suggestionId: String(created.id) };
      for (const admin of admins) {
        await createNotification(admin.id, { title: notifTitle, body: notifBody, data });
        await sendPushToUser({ userId: admin.id, title: notifTitle, body: notifBody, data });
      }
    } catch (e) {
      console.warn('No se pudo notificar a admins de nueva sugerencia:', e.message);
    }
    res.json(created);
  } catch (e) {
    console.error('createSuggestionController error', e);
    res.status(500).json({ message: 'Error al crear sugerencia' });
  }
}

async function listMySuggestionsController(req, res) {
  try {
    const user = req.user;
    const list = await suggestionModel.listSuggestionsByUser(user.id);
    res.json(list);
  } catch (e) {
    console.error('listMySuggestionsController error', e);
    res.status(500).json({ message: 'Error al listar sugerencias' });
  }
}

async function listAllSuggestionsController(req, res) {
  try {
    const user = req.user;
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ message: 'Solo administradores' });
    }
    const list = await suggestionModel.listAllSuggestions();
    res.json(list);
  } catch (e) {
    console.error('listAllSuggestionsController error', e);
    res.status(500).json({ message: 'Error al listar sugerencias' });
  }
}

async function updateSuggestionStatusController(req, res) {
  try {
    const user = req.user;
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ message: 'Solo administradores' });
    }
    const { id } = req.params;
    const { status } = req.body;
    const allowed = ['nuevo', 'revisando', 'resuelto', 'rechazado'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ message: 'Estado inválido' });
    }
    const updated = await suggestionModel.updateSuggestionStatus(Number(id), status);
    res.json(updated);
  } catch (e) {
    console.error('updateSuggestionStatusController error', e);
    res.status(500).json({ message: 'Error al actualizar estado' });
  }
}

async function deleteSuggestionController(req, res) {
  try {
    const user = req.user;
    if (!user || user.role !== 'admin') {
      return res.status(403).json({ message: 'Solo administradores' });
    }
    const { id } = req.params;
    await suggestionModel.deleteSuggestion(Number(id));
    res.json({ ok: true });
  } catch (e) {
    console.error('deleteSuggestionController error', e);
    res.status(500).json({ message: 'Error al eliminar sugerencia' });
  }
}

module.exports = {
  createSuggestionController,
  listMySuggestionsController,
  listAllSuggestionsController,
  updateSuggestionStatusController,
  deleteSuggestionController,
};
