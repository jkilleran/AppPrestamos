const nodemailer = require('nodemailer');
const { getSetting } = require('../models/settings.model');
const { sendViaHttpProvider, httpProviderAvailable } = require('./emailHttpProvider');

function parsePortEnv(raw) {
  if (!raw) return 587;
  const first = String(raw).split(',')[0].trim();
  const n = parseInt(first, 10);
  return Number.isFinite(n) ? n : 587;
}

function buildTransporterConfig() {
  const cfg = {
    host: process.env.SMTP_HOST,
    port: parsePortEnv(process.env.SMTP_PORT),
    secure: process.env.SMTP_SECURE === 'true',
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
  };
  if (process.env.SMTP_FORCE_IPV4 === '1') {
    cfg.family = 4; // Fuerza resolución IPv4 para evitar timeouts en algunos entornos
  }
  if (!cfg.host) throw new Error('SMTP no configurado (host)');
  return cfg;
}

async function resolveFrom() {
  const fromSetting = await getSetting('document_from_email');
  return fromSetting || process.env.DOCUMENT_FROM_EMAIL || process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com';
}

async function sendEmail({ to, subject, text, replyTo }) {
  if (!to) throw new Error('Destinatario requerido');
  const transporter = nodemailer.createTransport(buildTransporterConfig());
  const from = await resolveFrom();
  const payload = { from, to, subject, text, replyTo };
  const forceHttp = process.env.EMAIL_HTTP_FORCE === '1' && httpProviderAvailable();
  if (forceHttp) {
    try {
      const r = await sendViaHttpProvider({ to, from, subject, text, html: undefined, attachments: undefined });
      if (process.env.NOTIFIER_DEBUG === '1') console.log('[notifier] Enviado via HTTP', r);
      return;
    } catch (e) {
      console.error('[notifier] Error HTTP force:', e.message);
      return; // no fallback adicional
    }
  }
  try {
    const info = await transporter.sendMail(payload);
    if (process.env.NOTIFIER_DEBUG === '1') {
      console.log('[notifier] Email enviado', {
        to,
        subject,
        messageId: info?.messageId,
        accepted: info?.accepted,
        rejected: info?.rejected,
        response: info?.response?.substring?.(0,160),
      });
    }
  } catch (e) {
    const timeoutLikeCodes = ['ETIMEDOUT','ESOCKET','ECONNECTION'];
    const isTimeoutLike = timeoutLikeCodes.includes(e.code) || /timeout|socket/i.test(e.message || '');
    console.error('[notifier] Error enviando email SMTP:', e.message, 'code=', e.code);
    if (isTimeoutLike && httpProviderAvailable()) {
      try {
        const r = await sendViaHttpProvider({ to, from, subject, text, html: undefined, attachments: undefined });
        if (process.env.NOTIFIER_DEBUG === '1') console.log('[notifier] Fallback HTTP ok', r);
        return;
      } catch (eh) {
        console.error('[notifier] Fallback HTTP fallo:', eh.message);
      }
    }
  }
}

async function notifyLoanStatusChange({ user, loan, newStatus }) {
  if (!user || !user.email) return;
  const subject = `Tu solicitud de préstamo #${loan?.id || ''} fue actualizada a: ${newStatus}`;
  const text = [
    `Hola ${user.name || ''},`,
    '',
    `El estado de tu solicitud de préstamo ${loan?.id ? '#' + loan.id : ''} cambió a: ${newStatus}.`,
    loan?.amount ? `Monto: ${loan.amount}` : '',
    loan?.months ? `Plazo: ${loan.months} meses` : '',
    '',
    'Ingresa a la app para ver los detalles.',
  ].filter(Boolean).join('\n');
  await sendEmail({ to: user.email, subject, text });
}

async function notifyDocumentStatusCodeChange({ user, code }) {
  if (!user || !user.email) return;
  const subject = 'Se actualizó el estado de tus documentos';
  const text = [
    `Hola ${user.name || ''},`,
    '',
    `Se actualizó el estado de tus documentos. Código actual: ${code}.`,
    'Ingresa a la app para ver el detalle por documento.',
  ].join('\n');
  await sendEmail({ to: user.email, subject, text });
}

module.exports = {
  sendEmail,
  notifyLoanStatusChange,
  notifyDocumentStatusCodeChange,
};
