#!/usr/bin/env node
// Standalone SMTP self-test script.
// Usage (in backend directory): node scripts/smtp_self_test.js
// Requires env vars: SMTP_HOST, SMTP_PORT, SMTP_SECURE (true/false), SMTP_USER, SMTP_PASS
// Optional: DOCUMENT_TARGET_EMAIL or DEFAULT_TARGET_EMAIL or MAIL_FROM for destination.

require('dotenv').config();
const nodemailer = require('nodemailer');

function out(type, msg, extra){
  const base = `[SMTP_SELF_TEST] ${type}`;
  if (extra !== undefined) {
    console.log(base, msg, extra);
  } else {
    console.log(base, msg);
  }
}

function classify(err){
  if (!err) return 'unknown';
  if (/ENOTFOUND/.test(err.message) || err.code === 'ENOTFOUND') return 'DNS: host no encontrado';
  if (err.code === 'ECONNECTION') return 'Conexion rechazada / firewall';
  if (err.code === 'ETIMEDOUT' || err.code === 'ESOCKET') return 'Timeout de socket (puerto bloqueado o latencia)';
  if (err.code === 'EAUTH' || /Invalid login/i.test(err.message)) return 'Credenciales inválidas (App Password incorrecta)';
  if (/TLS/i.test(err.message) && /wrong version/i.test(err.message)) return 'Fallo TLS: secure/puerto incorrectos';
  return 'Otro error SMTP: ' + err.message.substring(0,140);
}

(async () => {
  const cfg = {
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    connectionTimeout: 10000,
    socketTimeout: 15000,
    greetingTimeout: 8000,
    logger: false,
  };

  const dest = process.env.DOCUMENT_TARGET_EMAIL || process.env.DEFAULT_TARGET_EMAIL || process.env.MAIL_FROM || process.env.SMTP_USER;
  const from = process.env.MAIL_FROM || process.env.SMTP_USER;

  out('INFO','Config (sanitizada):', { host: cfg.host, port: cfg.port, secure: cfg.secure, user: cfg.auth?.user, hasPass: !!cfg.auth?.pass, to: dest, from });

  if (!cfg.host) { out('ERROR','Falta SMTP_HOST'); process.exit(2); }
  if (!cfg.auth || !cfg.auth.user || !cfg.auth.pass) { out('ERROR','Falta SMTP_USER o SMTP_PASS'); process.exit(2); }
  if (!dest) { out('ERROR','No se definió destinatario (DOCUMENT_TARGET_EMAIL / DEFAULT_TARGET_EMAIL / MAIL_FROM)'); process.exit(2); }

  const transporter = nodemailer.createTransport(cfg);
  out('STEP','Verificando conexión y credenciales...');
  try {
    await transporter.verify();
    out('OK','verify() exitoso');
  } catch (e) {
    out('FAIL','verify() falló', { error: e.message, class: classify(e) });
    process.exit(3);
  }

  out('STEP','Enviando email de prueba...');
  const start = Date.now();
  try {
    await transporter.sendMail({
      from,
      to: dest,
      subject: 'SMTP SELF TEST',
      text: 'Prueba simple de envío desde smtp_self_test.js (' + new Date().toISOString() + ')'
    });
    out('OK','Email enviado', { ms: Date.now() - start });
    process.exit(0);
  } catch (e) {
    out('FAIL','sendMail falló', { error: e.message, code: e.code, class: classify(e) });
    process.exit(4);
  }
})();
