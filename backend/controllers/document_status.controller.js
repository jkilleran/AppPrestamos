// Controlador para el status de documentos
const db = require('../db');
const { findUserByEmail, findUserById, findUserByCedula } = require('../models/user.model');
const { notifyDocumentStatusCodeChange } = require('../services/notifier');
const { sendPushToUser } = require('../services/push');
const { createNotification } = require('../models/notification.model');

// Helpers to produce human-readable document status
const DOC_LABEL = {
  cedula: 'Cédula de identidad',
  estadoCuenta: 'Estado de cuenta',
  cartaTrabajo: 'Carta de Trabajo',
  videoAceptacion: 'Video de aceptación de préstamo',
};
function prettyState(s) {
  return s === 'enviado' ? 'Enviado' : (s === 'error' ? 'Error' : 'Pendiente');
}
function decodeStatusMap(code) {
  // Order must match the client packing order
  const order = ['cedula', 'estadoCuenta', 'cartaTrabajo', 'videoAceptacion'];
  const map = {};
  const n = order.length;
  for (let i = 0; i < n; i++) {
    const shift = (n - 1 - i) * 2;
    const bits = (code >> shift) & 0x3;
    map[order[i]] = bits === 1 ? 'enviado' : (bits === 2 ? 'error' : 'pendiente');
  }
  return map;
}

// Catálogo de errores predefinidos que puede seleccionar el admin
const DEFAULT_DOC_ERRORS = {
  cedula: [
    'Imagen borrosa',
    'Documento incompleto (faltan caras)',
    'Documento vencido',
    'Datos no legibles',
  ],
  estadoCuenta: [
    'Estado de cuenta ilegible',
    'Documento desactualizado (más de 60 días)',
    'Faltan páginas',
  ],
  cartaTrabajo: [
    'Carta sin firma o sello',
    'Carta vencida (más de 30 días)',
    'Datos de salario inconsistentes',
  ],
  videoAceptacion: [
    'Audio inaudible',
    'Identidad no clara en video',
    'Video demasiado corto (<10s)',
  ],
};

// GET: Obtener el status de documentos del usuario autenticado
exports.getUserDocumentStatus = async (req, res) => {
  try {
    console.log('GET /api/document-status - req.user:', req.user);
    const userId = req.user.id;
    console.log('GET /api/document-status - userId extraído:', userId);
    const result = await db.query('SELECT document_status_code, document_status_notes FROM users WHERE id = $1', [userId]);
    if (result.rows.length === 0) {
      console.log('GET /api/document-status - Usuario no encontrado para id:', userId);
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json({
      document_status_code: result.rows[0].document_status_code,
      notes: result.rows[0].document_status_notes || {},
    });
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
  const { document_status_code, doc, state } = req.body;

    // Read previous code to compute diffs when doc/state aren't provided
    let prevCode = null;
    try {
      const r = await db.query('SELECT document_status_code FROM users WHERE id = $1', [userId]);
      if (r.rows.length) prevCode = r.rows[0].document_status_code;
    } catch (e) {
      console.warn('WARN reading previous document_status_code:', e.message);
    }

  await db.query('UPDATE users SET document_status_code = $1 WHERE id = $2', [document_status_code, userId]);

    // Notificar al usuario (similar a préstamos) cuando cambia el estado
    try {
      const user = await findUserById(userId);
      // Prefer friendly body using provided doc/state, else compute diff
      let friendlyBody = null;
      if (doc && state) {
        const label = DOC_LABEL[doc] || null;
        friendlyBody = label ? `${label}: ${prettyState(state)}` : `Estado actualizado: ${prettyState(state)}`;
      } else if (prevCode !== null && Number.isInteger(document_status_code)) {
        try {
          const before = decodeStatusMap(Number(prevCode));
          const after = decodeStatusMap(Number(document_status_code));
          const changes = [];
          for (const k of Object.keys(after)) {
            if (before[k] !== after[k]) changes.push(`${DOC_LABEL[k] || k}: ${prettyState(after[k])}`);
          }
          if (changes.length === 1) friendlyBody = changes[0];
          else if (changes.length > 1) friendlyBody = `Se actualizaron documentos: ${changes.join(' · ')}`;
        } catch (e) {
          // fall back below
        }
      }
      if (!friendlyBody) friendlyBody = 'Se actualizó el estado de tus documentos.';

      await createNotification(userId, {
        title: 'Actualización de documentos',
        body: friendlyBody,
        data: { type: 'document_status', code: document_status_code, doc: doc || null, state: state || null },
      });
      await sendPushToUser({
        userId,
        title: 'Actualización de documentos',
        body: friendlyBody,
        data: { type: 'document_status', code: String(document_status_code), doc: doc || undefined, state: state || undefined },
      });
      // Email opcional
      notifyDocumentStatusCodeChange({ user, code: document_status_code });
    } catch (e) {
      console.warn('notify self document status change fallo:', e.message);
    }

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
    const result = await db.query('SELECT document_status_code, document_status_notes FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({
      document_status_code: result.rows[0].document_status_code,
      notes: result.rows[0].document_status_notes || {},
      defaults: DEFAULT_DOC_ERRORS,
    });
  } catch (err) {
    console.error('ADMIN GET by-email error:', err);
    res.status(500).json({ error: 'Error al obtener el status por email' });
  }
};

// GET admin: obtener status por cédula
exports.getDocumentStatusByCedula = async (req, res) => {
  try {
    const { cedula } = req.query;
    if (!cedula) return res.status(400).json({ error: 'Cédula requerida' });
    console.log('ADMIN GET /api/document-status/by-cedula cedula:', cedula);
    const result = await db.query('SELECT document_status_code, document_status_notes FROM users WHERE cedula = $1', [cedula]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({
      document_status_code: result.rows[0].document_status_code,
      notes: result.rows[0].document_status_notes || {},
      defaults: DEFAULT_DOC_ERRORS,
    });
  } catch (err) {
    console.error('ADMIN GET by-cedula error:', err);
    res.status(500).json({ error: 'Error al obtener el status por cédula' });
  }
};

// PUT admin: actualizar status de documentos por email (requiere rol admin)
exports.updateDocumentStatusByEmail = async (req, res) => {
  try {
    const { email, document_status_code, doc, state, note } = req.body;
    if (!email) return res.status(400).json({ error: 'Email requerido' });
    console.log('ADMIN PUT /api/document-status/by-email email:', email, 'code:', document_status_code);
    // Read previous code first for diff-friendly messages
    let prevCode = null;
    try {
      const r = await db.query('SELECT document_status_code FROM users WHERE email = $1', [email]);
      if (r.rows.length) prevCode = r.rows[0].document_status_code;
    } catch (e) {
      console.warn('WARN reading previous code by email:', e.message);
    }
    // Si viene note + doc y state == 'error', actualizamos JSON de notas
    let noteToApply = null;
    if (note && doc && state === 'error') {
      const label = DOC_LABEL[doc] || doc;
      noteToApply = note.toString().trim().slice(0, 300);
    }
    if (noteToApply) {
      // Merge incremental sobre JSON existente
      await db.query(`
        UPDATE users
        SET document_status_code = $1,
            document_status_notes = COALESCE(document_status_notes, '{}'::jsonb) || jsonb_build_object($3, jsonb_build_object('note', $4, 'updated_at', NOW()))
        WHERE email = $2
      `, [document_status_code, email, doc, noteToApply]);
    } else {
      await db.query('UPDATE users SET document_status_code = $1 WHERE email = $2', [document_status_code, email]);
    }
    const result = await db.query('SELECT id, document_status_notes FROM users WHERE email = $1', [email]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
    try {
      const user = await findUserByEmail(email);
      const docLabel = DOC_LABEL[doc] || null;
      let friendlyBody = null;
      if (docLabel && state) {
        friendlyBody = `${docLabel}: ${prettyState(state)}`;
      } else if (prevCode !== null && Number.isInteger(document_status_code)) {
        try {
          const before = decodeStatusMap(Number(prevCode));
          const after = decodeStatusMap(Number(document_status_code));
          const changes = [];
          for (const k of Object.keys(after)) {
            if (before[k] !== after[k]) changes.push(`${DOC_LABEL[k] || k}: ${prettyState(after[k])}`);
          }
          if (changes.length === 1) friendlyBody = changes[0];
          else if (changes.length > 1) friendlyBody = `Se actualizaron documentos: ${changes.join(' · ')}`;
        } catch (_) {}
      }
      if (!friendlyBody) friendlyBody = 'Se actualizó el estado de tus documentos.';

      notifyDocumentStatusCodeChange({ user, code: document_status_code });
      const dataPayload = { type: 'document_status', code: document_status_code, doc: doc || null, state: state || null };
      if (noteToApply) dataPayload.note = noteToApply;
      await createNotification(user.id, {
        title: 'Actualización de documentos',
        body: noteToApply ? `${friendlyBody} · ${noteToApply}` : friendlyBody,
        data: dataPayload,
      });
      await sendPushToUser({
        userId: user.id,
        title: 'Actualización de documentos',
        body: noteToApply ? `${friendlyBody} · ${noteToApply}` : friendlyBody,
        data: { ...dataPayload, code: String(document_status_code) },
      });
    } catch (e) {
      console.warn('notifyDocumentStatusCodeChange fallo:', e.message);
    }
    res.json({ success: true, notes: result.rows[0].document_status_notes || {}, defaults: DEFAULT_DOC_ERRORS });
  } catch (err) {
    console.error('ADMIN PUT by-email error:', err);
    res.status(500).json({ error: 'Error al actualizar el status por email' });
  }
};

// PUT admin: actualizar status por cédula
exports.updateDocumentStatusByCedula = async (req, res) => {
  try {
    const { cedula, document_status_code, doc, state, note } = req.body;
    if (!cedula) return res.status(400).json({ error: 'Cédula requerida' });
    console.log('ADMIN PUT /api/document-status/by-cedula cedula:', cedula, 'code:', document_status_code);
    let prevCode = null;
    try {
      const r = await db.query('SELECT document_status_code FROM users WHERE cedula = $1', [cedula]);
      if (r.rows.length) prevCode = r.rows[0].document_status_code;
    } catch (e) {
      console.warn('WARN reading previous code by cedula:', e.message);
    }
    let noteToApply = null;
    if (note && doc && state === 'error') {
      noteToApply = note.toString().trim().slice(0, 300);
    }
    if (noteToApply) {
      await db.query(`
        UPDATE users
        SET document_status_code = $1,
            document_status_notes = COALESCE(document_status_notes, '{}'::jsonb) || jsonb_build_object($3, jsonb_build_object('note', $4, 'updated_at', NOW()))
        WHERE cedula = $2
      `, [document_status_code, cedula, doc, noteToApply]);
    } else {
      await db.query('UPDATE users SET document_status_code = $1 WHERE cedula = $2', [document_status_code, cedula]);
    }
    const result = await db.query('SELECT id, document_status_notes, email FROM users WHERE cedula = $1', [cedula]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
    try {
      const user = await findUserByCedula(cedula); // incluye id, email, etc.
      const docLabel = DOC_LABEL[doc] || null;
      let friendlyBody = null;
      if (docLabel && state) {
        friendlyBody = `${docLabel}: ${prettyState(state)}`;
      } else if (prevCode !== null && Number.isInteger(document_status_code)) {
        try {
          const before = decodeStatusMap(Number(prevCode));
          const after = decodeStatusMap(Number(document_status_code));
          const changes = [];
          for (const k of Object.keys(after)) {
            if (before[k] !== after[k]) changes.push(`${DOC_LABEL[k] || k}: ${prettyState(after[k])}`);
          }
          if (changes.length === 1) friendlyBody = changes[0];
          else if (changes.length > 1) friendlyBody = `Se actualizaron documentos: ${changes.join(' · ')}`;
        } catch (_) {}
      }
      if (!friendlyBody) friendlyBody = 'Se actualizó el estado de tus documentos.';
      const dataPayload = { type: 'document_status', code: document_status_code, doc: doc || null, state: state || null };
      if (noteToApply) dataPayload.note = noteToApply;
      await createNotification(user.id, {
        title: 'Actualización de documentos',
        body: noteToApply ? `${friendlyBody} · ${noteToApply}` : friendlyBody,
        data: dataPayload,
      });
      await sendPushToUser({
        userId: user.id,
        title: 'Actualización de documentos',
        body: noteToApply ? `${friendlyBody} · ${noteToApply}` : friendlyBody,
        data: { ...dataPayload, code: String(document_status_code) },
      });
      notifyDocumentStatusCodeChange({ user, code: document_status_code });
    } catch (e) {
      console.warn('notifyDocumentStatusCodeChange fallo (cedula):', e.message);
    }
    res.json({ success: true, notes: result.rows[0].document_status_notes || {}, defaults: DEFAULT_DOC_ERRORS });
  } catch (err) {
    console.error('ADMIN PUT by-cedula error:', err);
    res.status(500).json({ error: 'Error al actualizar el status por cédula' });
  }
};
