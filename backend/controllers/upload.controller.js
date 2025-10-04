const multer = require('multer');
const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');
const { getSetting } = require('../models/settings.model');
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
// Ahora permitimos cualquier tipo de archivo. Si se quiere volver a restringir,
// se puede definir ALLOWED_MIME como lista específica o usar la variable de entorno
// RESTRICT_UPLOAD_MIME=1 para activar la validación clásica.
const DEFAULT_ALLOWED_MIME = [
  'image/jpeg','image/png','image/jpg','application/pdf'
];
const RESTRICT_MIME = process.env.RESTRICT_UPLOAD_MIME === '1';
const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB
  fileFilter: (req, file, cb) => {
    if (RESTRICT_MIME) {
      if (!DEFAULT_ALLOWED_MIME.includes(file.mimetype)) {
        const err = new Error('Tipo de archivo no permitido (solo JPG, PNG, PDF)');
        err.code = 'UNSUPPORTED_MIME';
        return cb(err);
      }
    }
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
  const docType = req.body.type || 'desconocido';
  const originalName = req.file?.originalname || 'archivo';
  const userEmail = (user.email || '').trim();
  const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  return { user, docType, originalName, userEmail, emailRegex };
}

function buildMailPayload({ from, replyTo, target, docType, originalName, user }) {
  const fullName = user.name || 'N/D';
  const userEmailForBody = user.email || 'N/D';
  const userId = user.id || 'N/D';
  const userRole = user.role || 'N/D';
  const subject = `Documento (${docType}) - ${fullName} (${userEmailForBody})`;
  const text = [
    `Tipo de documento: ${docType}`,
    `Usuario: ${fullName} <${userEmailForBody}>`,
    `ID usuario: ${userId}`,
    `Rol: ${userRole}`,
    `Archivo: ${originalName}`,
  ].join('\n');
  return { from, to: target, subject, text, replyTo, headers: {
      'X-Doc-Type': docType,
      'X-User-Id': String(userId),
      'X-User-Email': String(userEmailForBody),
      'X-User-Name': String(fullName),
      'X-User-Role': String(userRole),
    } };
}

async function sendDocumentEmail(req, res) {
  try {
    dbg('Inicio sendDocumentEmail');
  const { user, docType, originalName, userEmail, emailRegex } = buildMailContext(req);
    dbg('Usuario', user.id, user.email, 'Tipo doc', docType);
    if (!req.file) {
      dbg('Falta archivo');
      return res.status(400).json({ error: 'Archivo requerido' });
    }
    dbg('Archivo recibido', { originalname: req.file.originalname, size: req.file.size, mime: req.file.mimetype });
    if (req.file.size > 8 * 1024 * 1024) {
      return res.status(400).json({ error: 'Archivo supera el límite de 8MB' });
    }
    // Ya no validamos mimetype salvo que RESTRICT_UPLOAD_MIME esté activo.
    if (RESTRICT_MIME && !DEFAULT_ALLOWED_MIME.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Tipo de archivo no permitido (solo JPG, PNG, PDF)' });
    }

    // Determine destination email: setting first, else env fallback
  let target = await cachedSetting('document_target_email');
  dbg('Valor en settings document_target_email:', target);
  if (!target) target = process.env.DOCUMENT_TARGET_EMAIL || process.env.DEFAULT_TARGET_EMAIL;
  dbg('Destino final elegido:', target);
    if (!target) {
      return res.status(500).json({ error: 'Email destino no configurado' });
    }

    // Configure transporter (for simplicity use SMTP credentials from env)
    const transporterConfig = {
      host: process.env.SMTP_HOST,
      port: parsePortEnv(process.env.SMTP_PORT),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
      connectionTimeout: parseInt(process.env.SMTP_CONN_TIMEOUT || '12000', 10), // ms
      socketTimeout: parseInt(process.env.SMTP_SOCKET_TIMEOUT || '20000', 10),
      greetingTimeout: parseInt(process.env.SMTP_GREETING_TIMEOUT || '10000', 10),
      logger: process.env.UPLOAD_DEBUG === '1',
      debug: process.env.UPLOAD_DEBUG === '1',
    };
    if (process.env.SMTP_FORCE_IPV4 === '1') {
      transporterConfig.family = 4;
    }
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

  // Si el usuario autenticado tiene email, lo usamos como remitente directo;
  // si el SMTP no permite dominios arbitrarios, al menos irá en Reply-To.
  let fromSetting = await cachedSetting('document_from_email');
  const fallbackFrom = fromSetting || process.env.DOCUMENT_FROM_EMAIL || process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com';
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
    const baseMail = buildMailPayload({ from, replyTo, target, docType, originalName, user });
    const mailPayload = { ...baseMail, attachments: [ { filename: originalName, content: req.file.buffer } ] };
    dbg('Enviando email payload (sin buffer):', { ...mailPayload, attachments: [{ filename: originalName, size: req.file.size }] });
    const hardTimeoutMs = parseInt(process.env.SMTP_HARD_TIMEOUT || '25000', 10);

    // Modo asíncrono: se encola y respondemos de inmediato
    if (process.env.EMAIL_ASYNC === '1') {
      queueEmailSend({ transporter, mailPayload, hardTimeoutMs });
      const persist = process.env.EMAIL_OUTBOX === '1';
      return res.json({ ok: true, queued: true, message: persist ? 'Documento registrado para envío (outbox)' : 'Documento en cola para enviar', outbox: persist });
    }

    // Sin modo asíncrono: envío directo con timeout
    async function sendWithTimeout(cfg) {
      const localTransporter = cfg === transporterConfig ? transporter : nodemailer.createTransport(cfg);
      const info = await Promise.race([
        localTransporter.sendMail(mailPayload),
        new Promise((_, reject) => setTimeout(() => reject(new Error('TIMEOUT_ENVIO_EMAIL')), hardTimeoutMs)),
      ]);
      // Log enriquecido de diagnóstico
      if (process.env.UPLOAD_DEBUG === '1') {
        dbg('Resultado SMTP', {
          messageId: info?.messageId,
          accepted: info?.accepted,
          rejected: info?.rejected,
          response: info?.response?.substring?.(0, 160),
          envelope: info?.envelope,
        });
      }
      return info;
    }
    dbg('Enviando email (timeout ms =', hardTimeoutMs, ') usando', transporterConfig.host + ':' + transporterConfig.port, 'secure=' + transporterConfig.secure, '...');
    const started = Date.now();
    try {
      const info = await sendWithTimeout(transporterConfig);
      const elapsedOk = Date.now() - started;
      dbg('Email enviado OK en', elapsedOk, 'ms messageId=', info?.messageId);
      return res.json({ ok: true, message: 'Documento enviado', messageId: info?.messageId || null, elapsed_ms: elapsedOk });
    } catch (mailErr) {
      const elapsed = Date.now() - started;
      dbg('Fallo envío primario tras', elapsed, 'ms code:', mailErr.code, 'msg:', mailErr.message);
      const fallbackCfg = buildFallbackConfigIfEnabled(transporterConfig, mailErr);
      if (fallbackCfg) {
        try {
          const fbStart = Date.now();
          await sendWithTimeout(fallbackCfg);
          dbg('Email enviado OK (fallback) en', Date.now() - fbStart, 'ms');
          return res.json({ ok: true, message: 'Documento enviado (fallback)', fallback: { host: fallbackCfg.host, port: fallbackCfg.port, secure: fallbackCfg.secure } });
        } catch (fbErr) {
          const fbElapsed = Date.now() - started;
          dbg('Fallo fallback tras', fbElapsed, 'ms code:', fbErr.code, 'msg:', fbErr.message);
        }
      }
      // Auto-degrade to async queue if enabled via env flag and error is timeout/connection related
      const timeoutLikeCodes = ['ETIMEDOUT','ESOCKET','ECONNECTION'];
      const isTimeoutLike = timeoutLikeCodes.includes(mailErr.code) || /timeout|socket/i.test(mailErr.message || '');
      if (process.env.EMAIL_ASYNC_ON_FAIL === '1' && isTimeoutLike) {
        dbg('Activando modo cola por fallo timeout/connection. Encolando y respondiendo OK al cliente.');
        // Reuse existing queue mechanism
        queueEmailSend({ transporter, mailPayload, hardTimeoutMs });
        return res.status(200).json({ ok: true, queued: true, degraded: true, reason: 'SMTP encolado tras timeout', elapsed_ms: elapsed, triedFallback: !!fallbackCfg });
      }
      let publicError = mailErr.message === 'TIMEOUT_ENVIO_EMAIL'
        ? 'Timeout enviando email (verifique conectividad SMTP)'
        : categorizeMailError(mailErr);
      // Modo emergencia: nunca devolver 500 si EMAIL_SOFT_FAIL=1
      if (process.env.EMAIL_SOFT_FAIL === '1') {
        try {
          // Intentar encolar si no se pudo enviar
          queueEmailSend({ transporter, mailPayload, hardTimeoutMs });
        } catch (_) { /* ignorar */ }
        return res.json({
          ok: true,
          message: 'Documento recibido (email pendiente por error SMTP)',
          softFail: true,
          triedFallback: !!fallbackCfg,
          error: publicError,
          degraded: true
        });
      }
      const baseResp = { error: 'Error enviando documento', reason: publicError, elapsed_ms: elapsed, triedFallback: !!fallbackCfg };
      if (process.env.UPLOAD_DEBUG === '1') baseResp.code = mailErr.code;
      return res.status(500).json(baseResp);
    }
  } catch (e) {
    console.error('Error enviando documento (outer):', e);
    res.status(500).json({ error: 'Error enviando documento', reason: e.message });
  }
}

async function testEmail(req, res) {
  try {
    dbg('Inicio testEmail');
  let target = await cachedSetting('document_target_email');
    if (!target) target = process.env.DOCUMENT_TARGET_EMAIL || process.env.DEFAULT_TARGET_EMAIL;
    if (!target) return res.status(500).json({ error: 'Email destino no configurado' });
  let fromSetting = await cachedSetting('document_from_email');
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
