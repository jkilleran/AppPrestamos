const multer = require('multer');
const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');
const { getSetting } = require('../models/settings.model');
require('dotenv').config();

// Multer config in memory (buffer) so we can send via email without persisting
const storage = multer.memoryStorage();
const ALLOWED_MIME = [
  'image/jpeg','image/png','image/jpg','application/pdf'
];
const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_MIME.includes(file.mimetype)) {
      const err = new Error('Tipo de archivo no permitido (solo JPG, PNG, PDF)');
      err.code = 'UNSUPPORTED_MIME';
      return cb(err);
    }
    cb(null, true);
  }
});

function dbg(...args) {
  if (process.env.UPLOAD_DEBUG === '1') {
    console.log('[UPLOAD]', ...args);
  }
}

async function sendDocumentEmail(req, res) {
  try {
    dbg('Inicio sendDocumentEmail');
  const user = req.user || {}; // from auth middleware (optional)
  const docType = req.body.type || 'desconocido';
    dbg('Usuario', user.id, user.email, 'Tipo doc', docType);
    if (!req.file) {
      dbg('Falta archivo');
      return res.status(400).json({ error: 'Archivo requerido' });
    }
    dbg('Archivo recibido', { originalname: req.file.originalname, size: req.file.size, mime: req.file.mimetype });
    if (req.file.size > 8 * 1024 * 1024) {
      return res.status(400).json({ error: 'Archivo supera el límite de 8MB' });
    }
    if (!ALLOWED_MIME.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Tipo de archivo no permitido (solo JPG, PNG, PDF)' });
    }

    // Determine destination email: setting first, else env fallback
  let target = await getSetting('document_target_email');
  dbg('Valor en settings document_target_email:', target);
  if (!target) target = process.env.DOCUMENT_TARGET_EMAIL || process.env.DEFAULT_TARGET_EMAIL;
  dbg('Destino final elegido:', target);
    if (!target) {
      return res.status(500).json({ error: 'Email destino no configurado' });
    }

    // Configure transporter (for simplicity use SMTP credentials from env)
    const transporterConfig = {
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587,
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    };
    dbg('Transporter config (sin pass):', { ...transporterConfig, auth: transporterConfig.auth ? { user: transporterConfig.auth.user } : undefined });
    if (!transporterConfig.host) {
      dbg('Falta SMTP_HOST en configuración');
      return res.status(500).json({ error: 'SMTP no configurado (host)' });
    }
    const transporter = nodemailer.createTransport(transporterConfig);
    // verify antes de enviar (solo si debug)
    if (process.env.UPLOAD_DEBUG === '1') {
      try {
        await transporter.verify();
        dbg('transporter.verify OK');
      } catch (verErr) {
        dbg('transporter.verify fallo:', verErr.message);
      }
    }

  const originalName = req.file.originalname;
  // Si el usuario autenticado tiene email, lo usamos como remitente directo;
  // si el SMTP no permite dominios arbitrarios, al menos irá en Reply-To.
  const userEmail = (user.email || '').trim();
  const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  let fromSetting = await getSetting('document_from_email');
  const fallbackFrom = fromSetting || process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com';
  let from = fallbackFrom;
  let replyTo = undefined;
  if (userEmail && emailRegex.test(userEmail)) {
    // Intentamos usar directamente el correo del usuario como From.
    from = userEmail;
    // Si se quiere obligar a usar dominio autorizado, se puede activar FORCED_FALLBACK_FROM.
    if (process.env.FORCED_FALLBACK_FROM === '1') {
      replyTo = userEmail;
      from = fallbackFrom; // Forzamos remitente autorizado.
    }
  }
  dbg('Remitente final:', from, 'Reply-To:', replyTo || '(none)', 'FallbackFrom:', fallbackFrom);
  // Datos del usuario para el correo
  const fullName = user.name || req.body.fullName || 'N/D';
  const userEmailForBody = user.email || req.body.email || 'N/D';
  const userId = user.id || req.body.userId || 'N/D';
  const userRole = user.role || req.body.userRole || 'N/D';
  const subject = `Documento (${docType}) - ${fullName} (${userEmailForBody})`;
  const text = [
    `Tipo de documento: ${docType}`,
    `Usuario: ${fullName} <${userEmailForBody}>`,
    `ID usuario: ${userId}`,
    `Rol: ${userRole}`,
    `Archivo: ${originalName}`,
  ].join('\n');

    const mailPayload = {
      from,
      to: target,
      subject,
      text,
      replyTo,
      headers: {
        'X-Doc-Type': docType,
        'X-User-Id': String(userId),
        'X-User-Email': String(userEmailForBody),
        'X-User-Name': String(fullName),
        'X-User-Role': String(userRole),
      },
      attachments: [
        { filename: originalName, content: req.file.buffer }
      ]
    };
    dbg('Enviando email payload (sin buffer):', { ...mailPayload, attachments: [{ filename: originalName, size: req.file.size }] });
    try {
      await transporter.sendMail(mailPayload);
      dbg('Email enviado OK');
    } catch (mailErr) {
      dbg('Fallo sendMail code:', mailErr.code, 'msg:', mailErr.message);
      const publicError = categorizeMailError(mailErr);
      return res.status(500).json({ error: 'Error enviando documento', reason: publicError });
    }

    res.json({ ok: true, message: 'Documento enviado' });
  } catch (e) {
    console.error('Error enviando documento (outer):', e);
    res.status(500).json({ error: 'Error enviando documento', reason: e.message });
  }
}

async function testEmail(req, res) {
  try {
    dbg('Inicio testEmail');
    let target = await getSetting('document_target_email');
    if (!target) target = process.env.DOCUMENT_TARGET_EMAIL || process.env.DEFAULT_TARGET_EMAIL;
    if (!target) return res.status(500).json({ error: 'Email destino no configurado' });
    let fromSetting = await getSetting('document_from_email');
    const from = fromSetting || process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com';
    const transporterConfig = {
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587,
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    };
    const transporter = nodemailer.createTransport(transporterConfig);
    // verify para diagnosticar
    let verifyResult = null;
    try {
      await transporter.verify();
      verifyResult = 'OK';
    } catch (verErr) {
      dbg('Fallo en verify:', verErr.message);
      verifyResult = 'ERROR: ' + verErr.message;
    }
    await transporter.sendMail({
      from,
      to: target,
      subject: 'TEST EMAIL DOCUMENTOS',
      text: 'Correo de prueba para verificar configuración SMTP y destino.'
    });
    dbg('Test email enviado a', target, 'desde', from);
    res.json({ ok: true, target, from, verify: verifyResult });
  } catch (e) {
    console.error('Error testEmail:', e);
    res.status(500).json({ error: 'Error enviando test', detail: e.message });
  }
}

function categorizeMailError(err) {
  if (!err) return 'desconocido';
  if (err.code === 'EAUTH') return 'Autenticación SMTP fallida';
  if (err.code === 'ENOTFOUND' || err.code === 'ECONNECTION') return 'No se pudo conectar al servidor SMTP';
  if (err.code === 'ETIMEDOUT' || err.code === 'ESOCKET') return 'Timeout o socket SMTP';
  if (err.response && err.response.includes('Relay access denied')) return 'Relé denegado (verifique remitente)';
  return 'Error SMTP: ' + err.message.substring(0, 120);
}

// Middleware base (sin manejo de errores explícito)
const uploadSingle = upload.single('document');

// Versión segura que captura errores de Multer y responde en JSON consistente
function uploadSingleSafe(req, res, next) {
  uploadSingle(req, res, (err) => {
    if (err) {
      dbg('Error Multer', err.code, err.message);
      console.error('[UPLOAD][MULTER]', err);
      let status = 400;
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(status).json({ error: 'Archivo supera el límite de 8MB', code: err.code });
      }
      if (err.code === 'UNSUPPORTED_MIME') {
        return res.status(status).json({ error: 'Tipo de archivo no permitido (solo JPG, PNG, PDF)', code: err.code });
      }
      // Otros errores internos de multer
      return res.status(500).json({ error: 'Error procesando archivo', code: err.code || 'MULTER_ERROR', detail: err.message });
    }
    next();
  });
}

module.exports = { uploadSingle, uploadSingleSafe, sendDocumentEmail, testEmail };
// Helper for admin to inspect effective config (no email sent)
async function emailConfig(req, res) {
  try {
    const user = req.user || {};
    const userEmail = user.email || null;
    const targetSetting = await getSetting('document_target_email');
    const fromSetting = await getSetting('document_from_email');
    const targetResolved = targetSetting || process.env.DOCUMENT_TARGET_EMAIL || process.env.DEFAULT_TARGET_EMAIL || null;
    const fallbackFrom = fromSetting || process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com';
    const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
    let fromResolved = fallbackFrom;
    let replyTo = null;
    const forced = process.env.FORCED_FALLBACK_FROM === '1';
    if (userEmail && emailRegex.test(userEmail)) {
      if (forced) {
        replyTo = userEmail;
      } else {
        fromResolved = userEmail;
      }
    }
    res.json({
      targetResolved,
      fromResolved,
      replyTo,
      fallbackFrom,
      targetSetting,
      fromSetting,
      forcedFallback: forced,
      smtp: {
        host: process.env.SMTP_HOST || null,
        port: process.env.SMTP_PORT || null,
        secure: process.env.SMTP_SECURE || null,
        hasUser: !!process.env.SMTP_USER,
      }
    });
  } catch (e) {
    res.status(500).json({ error: 'Error obteniendo configuración', detail: e.message });
  }
}

module.exports.emailConfig = emailConfig;
