// Servicio de envío HTTP (actualmente soporta SendGrid)
// Uso:
// const { sendViaHttpProvider, httpProviderAvailable } = require('./services/emailHttpProvider');
// await sendViaHttpProvider({ to, from, subject, text, attachments });
// attachments: [{ filename, content: <Buffer>, contentType? }]

const SUPPORTED = ['sendgrid'];

function httpProviderAvailable() {
  return SUPPORTED.includes(process.env.EMAIL_HTTP_PROVIDER);
}

function sanitizeEmail(e) {
  return (e || '').trim();
}

function mapAttachmentsSendGrid(list = []) {
  return list.map(a => ({
    content: Buffer.isBuffer(a.content) ? a.content.toString('base64') : (a.content || ''),
    filename: a.filename || 'file',
    type: a.contentType || 'application/octet-stream',
    disposition: 'attachment'
  }));
}

async function sendViaHttpProvider({ to, from, subject, text, html, attachments, bcc, headers }) {
  const provider = process.env.EMAIL_HTTP_PROVIDER;
  if (!SUPPORTED.includes(provider)) {
    throw new Error('Proveedor HTTP no soportado: ' + provider);
  }
  if (provider === 'sendgrid') {
    const key = process.env.SENDGRID_API_KEY;
    if (!key) throw new Error('SENDGRID_API_KEY no definido');
    const toClean = sanitizeEmail(to);
    const fromClean = sanitizeEmail(from);
    if (!toClean) throw new Error('Destinatario vacío');
    if (!fromClean) throw new Error('Remitente vacío');
    const personalization = { to: [{ email: toClean }] };
    if (bcc) {
      const bccList = Array.isArray(bcc) ? bcc : String(bcc).split(',').map(s => s.trim()).filter(Boolean);
      if (bccList.length) personalization.bcc = bccList.map(e => ({ email: e }));
    }
    const body = {
      personalizations: [personalization],
      from: { email: fromClean },
      subject: subject || '(sin asunto)',
      content: [{ type: html ? 'text/html' : 'text/plain', value: html || text || '' }],
    };
    if (headers && Object.keys(headers).length) {
      body.headers = headers;
    }
    if (attachments && attachments.length) {
      body.attachments = mapAttachmentsSendGrid(attachments);
    }
    // Sandbox mode para pruebas si EMAIL_HTTP_SANDBOX=1
    if (process.env.EMAIL_HTTP_SANDBOX === '1') {
      body.mail_settings = { sandbox_mode: { enable: true } };
    }
    const resp = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    if (process.env.EMAIL_HTTP_DEBUG === '1') {
      console.log('[EMAIL][HTTP][sendgrid] status', resp.status, 'x-message-id', resp.headers.get('x-message-id'));
    }
    if (resp.status === 202) {
      return { ok: true, provider: 'sendgrid', messageId: resp.headers.get('x-message-id') || null };
    }
    const errTxt = await resp.text().catch(() => '');
    throw new Error('SendGrid fallo status=' + resp.status + ' body=' + errTxt.slice(0,300));
  }
  throw new Error('Proveedor no implementado: ' + provider);
}

module.exports = { sendViaHttpProvider, httpProviderAvailable };