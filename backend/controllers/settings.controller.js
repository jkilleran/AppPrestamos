const { getSetting, setSetting } = require('../models/settings.model');

const TARGET_KEY = 'document_target_email';
const FROM_KEY = 'document_from_email';
const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

async function getDocumentTargetEmail(req, res) {
  try {
    const value = await getSetting(TARGET_KEY);
    res.json({ email: value });
  } catch (e) {
    res.status(500).json({ error: 'Error al obtener email destino' });
  }
}

async function updateDocumentTargetEmail(req, res) {
  try {
    const { email } = req.body;
    if (!email || !emailRegex.test(email)) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    await setSetting(TARGET_KEY, email.trim());
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Error al actualizar email destino' });
  }
}

async function getDocumentFromEmail(req, res) {
  try {
    const value = await getSetting(FROM_KEY);
    res.json({ email: value });
  } catch (e) {
    res.status(500).json({ error: 'Error al obtener email remitente' });
  }
}

async function updateDocumentFromEmail(req, res) {
  try {
    const { email } = req.body;
    if (!email || !emailRegex.test(email)) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    await setSetting(FROM_KEY, email.trim());
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Error al actualizar email remitente' });
  }
}

module.exports = { getDocumentTargetEmail, updateDocumentTargetEmail, getDocumentFromEmail, updateDocumentFromEmail };
