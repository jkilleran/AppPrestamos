// Controlador para el status de documentos
const db = require('../db');

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
