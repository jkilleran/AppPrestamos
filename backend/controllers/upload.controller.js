const multer = require('multer');
const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');
const { getSetting } = require('../models/settings.model');
require('dotenv').config();

// Multer config in memory (buffer) so we can send via email without persisting
const storage = multer.memoryStorage();
const upload = multer({ limits: { fileSize: 15 * 1024 * 1024 } }); // 15MB limit

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
    dbg('Archivo recibido', { originalname: req.file.originalname, size: req.file.size });

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
    const transporter = nodemailer.createTransport(transporterConfig);

  const originalName = req.file.originalname;
  // FROM configurable vía setting 'document_from_email' -> MAIL_FROM -> SMTP_USER -> fallback
  let fromSetting = await getSetting('document_from_email');
  const from = fromSetting || process.env.MAIL_FROM || process.env.SMTP_USER || 'no-reply@example.com';
  dbg('Remitente elegido:', from);
  const subject = `Documento (${docType}) enviado${user.email ? ' por ' + user.email : ''}`;
  const text = `Se adjunta documento tipo: ${docType}\nUsuario: ${user.email || 'N/D'}\nNombre archivo: ${originalName}`;

    const mailPayload = {
      from,
      to: target,
      subject,
      text,
      attachments: [
        { filename: originalName, content: req.file.buffer }
      ]
    };
    dbg('Enviando email payload (sin buffer):', { ...mailPayload, attachments: [{ filename: originalName, size: req.file.size }] });
    await transporter.sendMail(mailPayload);
    dbg('Email enviado OK');

    res.json({ ok: true, message: 'Documento enviado' });
  } catch (e) {
    console.error('Error enviando documento:', e);
    res.status(500).json({ error: 'Error enviando documento' });
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

module.exports = { uploadSingle: upload.single('document'), sendDocumentEmail, testEmail };
