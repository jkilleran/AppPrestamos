const pool = require('../db');
const nodemailer = require('nodemailer');
require('dotenv').config();

// Simple in-process worker that reads pending rows and sends them.
// Idempotency: relies on status transitions pending->sent/failed.

const MAX_ATTEMPTS = parseInt(process.env.EMAIL_MAX_ATTEMPTS || '5', 10);
const BATCH_SIZE = parseInt(process.env.EMAIL_BATCH_SIZE || '10', 10);
const INTERVAL_MS = parseInt(process.env.EMAIL_WORKER_INTERVAL_MS || '12000', 10);

let workerTimer = null;
let running = false;

function buildTransportConfig(){
  const cfg = {
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
    connectionTimeout: parseInt(process.env.SMTP_CONN_TIMEOUT || '12000', 10),
    socketTimeout: parseInt(process.env.SMTP_SOCKET_TIMEOUT || '20000', 10),
    greetingTimeout: parseInt(process.env.SMTP_GREETING_TIMEOUT || '10000', 10),
  };
  if (process.env.SMTP_FORCE_IPV4 === '1') cfg.family = 4;
  return cfg;
}

async function enqueueEmail({ target, subject, body, attachments }) {
  const res = await pool.query(
    `INSERT INTO email_outbox (target, subject, body, attachments)
     VALUES ($1,$2,$3,$4) RETURNING *`,
    [target, subject, body || null, attachments ? JSON.stringify(attachments) : null]
  );
  return res.rows[0];
}

async function fetchPending(limit) {
  const res = await pool.query(
    `SELECT * FROM email_outbox
       WHERE status = 'pending'
       ORDER BY created_at ASC
       LIMIT $1`, [limit]
  );
  return res.rows;
}

async function markSent(id) {
  await pool.query(`UPDATE email_outbox SET status='sent', attempts=attempts+1, updated_at=NOW() WHERE id=$1`, [id]);
}
async function markFailed(id, err, final) {
  await pool.query(`UPDATE email_outbox SET status=$2, attempts=attempts+1, last_error=$3, updated_at=NOW() WHERE id=$1`, [id, final ? 'failed' : 'pending', err.slice(0,300)]);
}

async function processBatch() {
  if (running) return; // simple reentrancy guard
  running = true;
  try {
    const pending = await fetchPending(BATCH_SIZE);
    if (!pending.length) return;
    const transportCfg = buildTransportConfig();
    if (!transportCfg.host) {
      console.warn('[OUTBOX] SMTP_HOST faltante, no se puede enviar lote');
      return;
    }
    const transporter = nodemailer.createTransport(transportCfg);
    for (const row of pending) {
      const attachments = row.attachments ? JSON.parse(row.attachments) : undefined;
      try {
        await transporter.sendMail({
          from: process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com',
            to: row.target,
            subject: row.subject,
            text: row.body || undefined,
            attachments
        });
        await markSent(row.id);
        if (process.env.EMAIL_OUTBOX_DEBUG === '1') console.log('[OUTBOX] sent id', row.id);
      } catch (e) {
        const attemptsRes = await pool.query('SELECT attempts FROM email_outbox WHERE id=$1', [row.id]);
        const attempts = attemptsRes.rows[0]?.attempts || 0;
        const final = attempts + 1 >= MAX_ATTEMPTS;
        await markFailed(row.id, e.message, final);
        console.warn('[OUTBOX] fail id', row.id, 'attempt', attempts+1, 'final?', final, e.message);
      }
    }
  } catch (e) {
    console.error('[OUTBOX] error batch', e.message);
  } finally {
    running = false;
  }
}

function startWorker() {
  if (workerTimer) return;
  if (process.env.EMAIL_OUTBOX_DISABLED === '1') {
    console.log('[OUTBOX] Deshabilitado por EMAIL_OUTBOX_DISABLED=1');
    return;
  }
  workerTimer = setInterval(processBatch, INTERVAL_MS).unref();
  console.log('[OUTBOX] Worker iniciado cada', INTERVAL_MS, 'ms');
}

function stopWorker(){
  if (workerTimer) clearInterval(workerTimer);
  workerTimer = null;
}

async function metrics() {
  const res = await pool.query(`SELECT status, COUNT(*)::int as c FROM email_outbox GROUP BY status`);
  const map = { pending:0, sent:0, failed:0 };
  res.rows.forEach(r => { map[r.status] = r.c; });
  return map;
}

module.exports = { enqueueEmail, startWorker, stopWorker, metrics };
