const multer = require('multer');
const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');
const { getSetting } = require('../models/settings.model');
const db = require('../db');
const { sendViaHttpProvider, httpProviderAvailable } = require('../services/emailHttpProvider');
let enqueueEmailOutbox = null;
try {
  // cargar perezosamente para no romper si no existe
  enqueueEmailOutbox = require('../services/emailOutbox').enqueueEmail;
} catch (_) { /* ignore */ }
require('dotenv').config();

function parsePortEnv(raw) {
  if (!raw) return 587;
  const first = String(raw).split(',')[0].trim();
  const n = parseInt(first, 10);
  return Number.isFinite(n) ? n : 587;
}

// Multer config in memory (buffer) so we can send via email without persisting
const storage = multer.memoryStorage();
// Permitir cualquier tipo de archivo (sin restricción de mimetype)
const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB
  fileFilter: (req, file, cb) => {
    cb(null, true);
  }
});

function dbg(...args) {
  if (process.env.UPLOAD_DEBUG === '1') {
    console.log('[UPLOAD]', ...args);
  }
}

// ---------------- SMTP fallback helper ----------------
function buildFallbackConfigIfEnabled(primaryCfg, lastError) {
  try {
    if (process.env.SMTP_ENABLE_FALLBACK !== '1') return null;
    // Only fallback if primary is classic implicit TLS 465 OR explicit request via env
    const timeoutLike = lastError && (
      ['ETIMEDOUT','ECONNECTION','ESOCKET'].includes(lastError.code) || /timeout/i.test(lastError.message || '')
    );
    if (!timeoutLike) return null; // only on connection/timeout errors
    const force = process.env.SMTP_FORCE_FALLBACK === '1';
    if (!force && !(primaryCfg.port === 465 && primaryCfg.secure === true)) return null;
    const fbPort = parseInt(process.env.SMTP_FALLBACK_PORT || '587', 10);
    const fbSecure = process.env.SMTP_FALLBACK_SECURE === 'true'; // default false for STARTTLS
    const fbHost = process.env.SMTP_FALLBACK_HOST || primaryCfg.host;
    if (fbPort === primaryCfg.port && fbSecure === primaryCfg.secure && fbHost === primaryCfg.host) return null; // no change
    const fallbackCfg = {
      ...primaryCfg,
      host: fbHost,
      port: fbPort,
      secure: fbSecure,
      requireTLS: fbSecure ? undefined : true, // enforce STARTTLS upgrade if not secure implicit
    };
    dbg('Preparando fallback SMTP =>', { host: fallbackCfg.host, port: fallbackCfg.port, secure: fallbackCfg.secure });
    return fallbackCfg;
  } catch (e) {
    console.error('[UPLOAD][FALLBACK] Error construyendo fallback:', e.message);
    return null;
  }
}

// ---------------- In-memory email queue (simple) ----------------
const emailQueue = [];
let emailWorkerRunning = false;

function queueEmailSend({ transporter, mailPayload, hardTimeoutMs }) {
  // Si está activado modo outbox persistente, guardamos en DB y salimos.
  if (process.env.EMAIL_OUTBOX === '1' && enqueueEmailOutbox) {
    (async () => {
      try {
        const att = mailPayload.attachments?.map(a => ({ filename: a.filename, size: a.content?.length }));
        await enqueueEmailOutbox({
          target: mailPayload.to,
          subject: mailPayload.subject,
          body: mailPayload.text,
          attachments: mailPayload.attachments ? mailPayload.attachments.map(a => ({ filename: a.filename })) : null
        });
        dbg('Email registrado en outbox persistente');
      } catch (e) {
        console.error('[UPLOAD][OUTBOX] Error encolando en outbox', e.message);
      }
    })();
    return; // no usar cola en memoria
  }
  emailQueue.push({ transporterConfig: transporter.options, mailPayload, hardTimeoutMs, enqueuedAt: Date.now() });
  dbg('Email encolado. Largo actual:', emailQueue.length);
  runEmailWorker();
}

async function runEmailWorker() {
  if (emailWorkerRunning) return;
  emailWorkerRunning = true;
  while (emailQueue.length) {
    const job = emailQueue.shift();
    const { transporterConfig, mailPayload, hardTimeoutMs, enqueuedAt } = job;
    const waitMs = Date.now() - enqueuedAt;
    dbg('Procesando email (esperó', waitMs, 'ms en cola)');
    try {
      async function attemptSend(cfg) {
        const transporter = nodemailer.createTransport(cfg);
        const started = Date.now();
        await Promise.race([
          transporter.sendMail(mailPayload),
          new Promise((_, reject) => setTimeout(() => reject(new Error('TIMEOUT_ENVIO_EMAIL')), hardTimeoutMs)),
        ]);
        dbg('Email enviado (cola) usando', cfg.host + ':' + cfg.port, 'secure=' + cfg.secure, 'en', Date.now() - started, 'ms');
      }
      try {
        await attemptSend(transporterConfig);
      } catch (primaryErr) {
        console.error('[UPLOAD][QUEUE] Error primario envío:', primaryErr.code, primaryErr.message);
        const fallbackCfg = buildFallbackConfigIfEnabled(transporterConfig, primaryErr);
        if (fallbackCfg) {
          try {
            await attemptSend(fallbackCfg);
          } catch (fbErr) {
            console.error('[UPLOAD][QUEUE] Fallback también falló:', fbErr.code, fbErr.message);
          }
        }
      }
    } catch (e) {
      console.error('[UPLOAD][QUEUE] Error inesperado en worker:', e.message);
    }
  }
  emailWorkerRunning = false;
}

// Cache simple en memoria de settings para reducir queries repetidas
const SETTINGS_CACHE_TTL_MS = 60_000;
const settingsCache = new Map(); // key -> { value, expires }
async function cachedSetting(key) {
  const now = Date.now();
  const hit = settingsCache.get(key);
  if (hit && hit.expires > now) return hit.value;
  const val = await getSetting(key);
  settingsCache.set(key, { value: val, expires: now + SETTINGS_CACHE_TTL_MS });
  return val;
}

function buildMailContext(req) {
  const user = req.user || {};
  // aceptar body.type o body.docType por compatibilidad
  const docType = req.body.type || req.body.docType || 'desconocido';
  const originalName = req.file?.originalname || 'archivo';
  const userEmail = (user.email || '').trim();
  const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  return { user, docType, originalName, userEmail, emailRegex };
}

// --- Helpers para actualizar el bitmask document_status_code ---
// Orden debe coincidir con decodeStatusMap en document_status.controller.js
const DOC_ORDER = ['cedula', 'estadoCuenta', 'cartaTrabajo', 'videoAceptacion'];
function computeNewCode(prevCode, docType, state) {
  if (!DOC_ORDER.includes(docType)) return null; // desconocido, no tocamos
  const idx = DOC_ORDER.indexOf(docType);
  const n = DOC_ORDER.length;
  const shift = (n - 1 - idx) * 2;
  const clearMask = ~(0x3 << shift);
  const base = (Number.isInteger(prevCode) ? prevCode : 0) & clearMask;
  let valBits = 0; // pendiente
  if (state === 'enviado') valBits = 1; // 01
  else if (state === 'error') valBits = 2; // 10
  return base | (valBits << shift);
}
async function updateDocumentStatusBit(userId, docType, state) {
  if (process.env.AUTO_UPDATE_DOCUMENT_STATUS !== '1') return; // desactivado
  if (!Number.isInteger(userId)) return;
  if (!DOC_ORDER.includes(docType)) return;
  try {
    const prevRes = await db.query('SELECT document_status_code FROM users WHERE id=$1', [userId]);
    const prev = prevRes.rows.length ? prevRes.rows[0].document_status_code : 0;
    const next = computeNewCode(prev, docType, state);
    if (next === null || next === prev) return;
    await db.query('UPDATE users SET document_status_code=$1 WHERE id=$2', [next, userId]);
    if (process.env.UPLOAD_DEBUG === '1') dbg('document_status_code actualizado', { userId, docType, state, prev, next });
  } catch (e) {
    console.warn('[UPLOAD][DOC_STATUS] No se pudo actualizar bitmask:', e.message);
  }
}
function buildMailPayload({ from, replyTo, target, docType, originalName, user }) {
  const fullName = user.name || 'N/D';
  const userEmailForBody = user.email || 'N/D';
  const userId = user.id || 'N/D';
  const userRole = user.role || 'N/D';
  const trace = 'DOC-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
  const subject = `[Docs] ${docType} - ${fullName} (${userEmailForBody}) | ${trace}`;
  const text = [
    `Trace: ${trace}`,
    `Tipo de documento: ${docType}`,
    `Usuario: ${fullName} <${userEmailForBody}>`,
    `ID usuario: ${userId}`,
    `Rol: ${userRole}`,
    `Archivo: ${originalName}`,
  ].join('\n');
  const html = `<!DOCTYPE html><html><body style="font-family:Arial,Helvetica,sans-serif;line-height:1.4;color:#222;">
  <h2 style="margin:0 0 12px">Documento recibido</h2>
  <p><strong>Trace:</strong> ${trace}</p>
  <ul style="padding-left:16px">
    <li><strong>Tipo:</strong> ${docType}</li>
    <li><strong>Usuario:</strong> ${fullName} &lt;${userEmailForBody}&gt;</li>
    <li><strong>ID usuario:</strong> ${userId}</li>
    <li><strong>Rol:</strong> ${userRole}</li>
    <li><strong>Archivo:</strong> ${originalName}</li>
  </ul>
  <p style="font-size:12px;color:#666">Si no solicitaste esta acción puedes ignorar este correo. Trace ${trace}</p>
  </body></html>`;
  const headers = {
    'X-Doc-Type': docType,
    'X-User-Id': String(userId),
    'X-User-Email': String(userEmailForBody),
    'X-User-Name': String(fullName),
    'X-User-Role': String(userRole),
    'X-Trace-Token': trace,
  };
  return { from, to: target, subject, text, html, replyTo, headers, trace };
}

async function sendDocumentEmail(req, res) {
  try {
    dbg('Inicio sendDocumentEmail');
    const { user, docType, originalName } = buildMailContext(req);
    dbg('Usuario', user.id, user.email, 'Tipo doc', docType);
    if (!req.file) {
      dbg('Falta archivo');
      return res.status(400).json({ error: 'Archivo requerido' });
    }
    dbg('Archivo recibido', { originalname: req.file.originalname, size: req.file.size, mime: req.file.mimetype });
    if (req.file.size > 8 * 1024 * 1024) {
      return res.status(400).json({ error: 'Archivo supera el límite de 8MB' });
    }
    // Solo guardar el archivo, sin enviar email
    return res.json({ ok: true, message: 'Documento recibido y guardado (no se envió email)' });
}

async function testEmail(req, res) {
  try {
    dbg('Inicio testEmail');
    let target = await cachedSetting('document_target_email');
    if (!target) target = process.env.DOCUMENT_TARGET_EMAIL || process.env.DEFAULT_TARGET_EMAIL;
    if (!target) return res.status(500).json({ error: 'Email destino no configurado' });
    let fromSetting = await cachedSetting('document_from_email');
    let from = fromSetting || process.env.DOCUMENT_FROM_EMAIL || process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com';
    // Forzar remitente verificado en SendGrid
    if (process.env.EMAIL_HTTP_PROVIDER === 'sendgrid') {
      const verifiedFrom = process.env.DOCUMENT_FROM_EMAIL || process.env.MAIL_FROM || process.env.SMTP_USER || from;
      from = verifiedFrom;
    }

    const httpForce = process.env.EMAIL_HTTP_FORCE === '1' && httpProviderAvailable();
    if (httpForce) {
      try {
        const info = await sendViaHttpProvider({
          to: target,
          from,
          subject: 'TEST EMAIL (HTTP) '+ new Date().toISOString(),
          text: 'Prueba de canal HTTP (SendGrid) para documentos.',
          html: '<p><strong>Prueba HTTP OK</strong><br/>'+new Date().toISOString()+'</p>'
        });
        return res.json({ ok: true, channel: 'http', provider: info.provider, messageId: info.messageId, target, from });
      } catch (e) {
        return res.status(500).json({ error: 'Fallo test HTTP', detail: e.message });
      }
    }

    // Si no hay force, intentamos SMTP y si falla (timeout/conexión) probamos HTTP fallback
    const transporterConfig = {
      host: process.env.SMTP_HOST,
      port: parsePortEnv(process.env.SMTP_PORT),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    };
    if (!transporterConfig.host && httpProviderAvailable()) {
      // No SMTP configurado, usar HTTP directo aunque no esté force
      try {
        const info = await sendViaHttpProvider({
          to: target,
          from,
          subject: 'TEST EMAIL (HTTP sin SMTP) '+ new Date().toISOString(),
          text: 'Prueba HTTP (SMTP no configurado).',
          html: '<p>Prueba HTTP (sin SMTP) '+new Date().toISOString()+'</p>'
        });
        return res.json({ ok: true, channel: 'http', provider: info.provider, messageId: info.messageId, target, from, note: 'SMTP no definido' });
      } catch (e) {
        return res.status(500).json({ error: 'Fallo test HTTP (sin SMTP)', detail: e.message });
      }
    }
    const transporter = nodemailer.createTransport(transporterConfig);
    let verifyResult = null;
    try {
      await transporter.verify();
      verifyResult = 'OK';
    } catch (verErr) {
      verifyResult = 'ERROR: ' + verErr.message;
    }

    const start = Date.now();
    try {
      await transporter.sendMail({
        from,
        to: target,
        subject: 'TEST EMAIL (SMTP) '+ new Date().toISOString(),
        text: 'Prueba SMTP para documentos. verify='+verifyResult
      });
      return res.json({ ok: true, channel: 'smtp', verify: verifyResult, elapsed_ms: Date.now()-start, target, from });
    } catch (smtpErr) {
      const timeoutLike = ['ETIMEDOUT','ESOCKET','ECONNECTION'].includes(smtpErr.code) || /timeout|socket/i.test(smtpErr.message||'');
      if (timeoutLike && httpProviderAvailable()) {
        try {
          const info = await sendViaHttpProvider({
            to: target,
            from,
            subject: 'TEST EMAIL (HTTP fallback) '+ new Date().toISOString(),
            text: 'Fallback HTTP tras fallo SMTP: '+smtpErr.code,
            html: '<p>Fallback HTTP tras fallo SMTP '+(smtpErr.code||'')+'</p>'
          });
          return res.json({ ok: true, channel: 'http', provider: info.provider, messageId: info.messageId, degraded: true, smtp_error: smtpErr.code || smtpErr.message, target, from });
        } catch (e2) {
          return res.status(500).json({ error: 'SMTP falló y HTTP fallback también', smtp: smtpErr.message, http: e2.message });
        }
      }
      return res.status(500).json({ error: 'Fallo SMTP test', detail: smtpErr.message, verify: verifyResult });
    }
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
module.exports.queueEmailSend = queueEmailSend;
module.exports.buildMailContext = buildMailContext;
module.exports.buildMailPayload = buildMailPayload;
// Helper for admin to inspect effective config (no email sent)
async function emailConfig(req, res) {
  try {
    const user = req.user || {};
    const userEmail = user.email || null;
  const targetSetting = await cachedSetting('document_target_email');
  const fromSetting = await cachedSetting('document_from_email');
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
    // HTTP (SendGrid) provider flags so el admin puede verlos rápidamente
    const httpForce = process.env.EMAIL_HTTP_FORCE === '1';
    const httpSandbox = process.env.EMAIL_HTTP_SANDBOX === '1';
    const httpProvider = process.env.EMAIL_HTTP_PROVIDER || 'sendgrid';
    const httpDebug = process.env.EMAIL_HTTP_DEBUG === '1';
    const sendgridKeySet = !!process.env.SENDGRID_API_KEY;
    const httpAvailable = sendgridKeySet && httpProvider === 'sendgrid';
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
      },
      http: {
        provider: httpProvider,
        available: httpAvailable,
        force: httpForce,
        sandbox: httpSandbox,
        debug: httpDebug,
        apiKeySet: sendgridKeySet
      }
    });
  } catch (e) {
    res.status(500).json({ error: 'Error obteniendo configuración', detail: e.message });
  }
}

module.exports.emailConfig = emailConfig;
