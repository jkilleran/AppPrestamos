// Controlador para el status de documentos
const db = require('../db');
const { findUserByEmail, findUserById } = require('../models/user.model');
const { notifyDocumentStatusCodeChange } = require('../services/notifier');
const { sendPushToUser } = require('../services/push');
const { createNotification } = require('../models/notification.model');

// GET: Obtener el status de documentos del usuario autenticado
exports.getUserDocumentStatus = async (req, res) => {
  try {
    console.log('GET /api/document-status - req.user:', req.user);
    const userId = req.user.id;
    console.log('GET /api/document-status - userId extraído:', userId);
    const result = await db.query('SELECT document_status_code FROM users WHERE id = $1', [userId]);
    if (result.rows.length === 0) {
      console.log('GET /api/document-status - Usuario no encontrado para id:', userId);
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({ document_status_code: result.rows[0].document_status_code });
  } catch (err) {
    console.error('GET /api/document-status - Error:', err);
    res.status(500).json({ error: 'Error al obtener el status de documentos' });
  }
};

// PUT: Actualizar el status de documentos del usuario autenticado
exports.updateUserDocumentStatus = async (req, res) => {
  try {
    console.log('PUT /api/document-status - req.user:', req.user);
    const userId = req.user.id;
    console.log('PUT /api/document-status - userId extraído:', userId);
    const { document_status_code } = req.body;
  await db.query('UPDATE users SET document_status_code = $1 WHERE id = $2', [document_status_code, userId]);
    res.json({ success: true });
  } catch (err) {
    console.error('PUT /api/document-status - Error:', err);
    res.status(500).json({ error: 'Error al actualizar el status de documentos' });
  }
};

// GET admin: obtener status de documentos por email (requiere rol admin)
exports.getDocumentStatusByEmail = async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: 'Email requerido' });
    console.log('ADMIN GET /api/document-status/by-email email:', email);
    const result = await db.query('SELECT document_status_code FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({ document_status_code: result.rows[0].document_status_code });
  } catch (err) {
    console.error('ADMIN GET by-email error:', err);
    res.status(500).json({ error: 'Error al obtener el status por email' });
  }
};

// PUT admin: actualizar status de documentos por email (requiere rol admin)
exports.updateDocumentStatusByEmail = async (req, res) => {
  try {
    const { email, document_status_code } = req.body;
    if (!email) return res.status(400).json({ error: 'Email requerido' });
    console.log('ADMIN PUT /api/document-status/by-email email:', email, 'code:', document_status_code);
    const result = await db.query('UPDATE users SET document_status_code = $1 WHERE email = $2 RETURNING id', [document_status_code, email]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
    try {
      const user = await findUserByEmail(email);
      notifyDocumentStatusCodeChange({ user, code: document_status_code });
      await createNotification(user.id, {
        title: 'Actualización de documentos',
        body: `Código de estado: ${document_status_code}`,
        data: { type: 'document_status', code: document_status_code },
      });
      await sendPushToUser({
        userId: user.id,
        title: 'Actualización de documentos',
        body: `Código de estado: ${document_status_code}`,
        data: { type: 'document_status', code: String(document_status_code) },
      });
    } catch (e) {
      console.warn('notifyDocumentStatusCodeChange fallo:', e.message);
    }
    res.json({ success: true });
  } catch (err) {
    console.error('ADMIN PUT by-email error:', err);
    res.status(500).json({ error: 'Error al actualizar el status por email' });
  }
};
