const db = require('../db');
const multer = require('multer');
const PDFDocument = require('pdfkit');
const { PassThrough } = require('stream');
const path = require('path');
const { normalizeCedula, isValidCedula } = require('../utils/validation');

// IMPORTANT: This order must match Flutter's DocumentType enum order.
// If you add/reorder document types, update both backend + Flutter bitmask packing.
const STATUS_DOC_ORDER = ['cedula', 'estadoCuenta', 'cartaTrabajo', 'videoAceptacion'];

const ALLOWED_DOC_TYPES = new Set([
  'cedula',
  'estadoCuenta',
  'cartaTrabajo',
  'videoAceptacion',
]);

const DOC_LIMITS = {
  // Conservative defaults; can be tuned via env later if needed.
  defaultBytes: 8 * 1024 * 1024, // 8MB
  videoBytes: 50 * 1024 * 1024, // 50MB
};

const ALLOWED_MIME = {
  // NOTE: On some clients (especially web) the picker uploads as application/octet-stream.
  // We accept it here and later sniff the actual bytes to decide if it's PDF/image.
  cedula: new Set(['application/pdf', 'image/jpeg', 'image/png', 'application/octet-stream']),
  estadoCuenta: new Set(['application/pdf', 'image/jpeg', 'image/png', 'application/octet-stream']),
  cartaTrabajo: new Set(['application/pdf', 'image/jpeg', 'image/png', 'application/octet-stream']),
  videoAceptacion: new Set([
    'video/mp4',
    'video/quicktime',
    'video/x-m4v',
    'application/octet-stream',
  ]),
};

function sanitizeFilename(name) {
  if (!name) return '';
  return name
    .toString()
    .replace(/[/\\?%*:|"<>]/g, '_')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 180);
}

function extFromMime(mime) {
  const m = (mime || '').toLowerCase();
  if (m === 'application/pdf') return 'pdf';
  if (m === 'image/jpeg') return 'jpg';
  if (m === 'image/png') return 'png';
  if (m === 'video/mp4') return 'mp4';
  if (m === 'video/quicktime') return 'mov';
  if (m === 'video/x-m4v') return 'm4v';
  return 'bin';
}

function bufferLooksLikePdf(buf) {
  try {
    if (!buf || buf.length < 4) return false;
    return buf.slice(0, 4).toString('ascii') === '%PDF';
  } catch (_) {
    return false;
  }
}

function bufferLooksLikePng(buf) {
  return (
    !!buf &&
    buf.length >= 8 &&
    buf[0] === 0x89 &&
    buf[1] === 0x50 &&
    buf[2] === 0x4e &&
    buf[3] === 0x47 &&
    buf[4] === 0x0d &&
    buf[5] === 0x0a &&
    buf[6] === 0x1a &&
    buf[7] === 0x0a
  );
}

function bufferLooksLikeJpeg(buf) {
  return !!buf && buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff;
}

async function imageBufferToPdfBuffer(imageBuffer) {
  return await new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ autoFirstPage: false });
      const pass = new PassThrough();
      const chunks = [];
      pass.on('data', (c) => chunks.push(c));
      pass.on('end', () => resolve(Buffer.concat(chunks)));
      pass.on('error', reject);
      doc.pipe(pass);

      doc.addPage({ size: 'A4', margin: 36 });
      const pageW = doc.page.width - doc.page.margins.left - doc.page.margins.right;
      const pageH = doc.page.height - doc.page.margins.top - doc.page.margins.bottom;
      doc.image(imageBuffer, doc.page.margins.left, doc.page.margins.top, {
        fit: [pageW, pageH],
        align: 'center',
        valign: 'center',
      });
      doc.end();
    } catch (e) {
      reject(e);
    }
  });
}

function toPdfFilename(originalFilename, fallbackBase) {
  const safe = sanitizeFilename(originalFilename);
  const base = (safe || fallbackBase || '').replace(/\.[^/.]+$/, '').trim();
  const name = base || 'documento';
  return `${name}.pdf`;
}

function fallbackName({ docType, userId, mime, cedula }) {
  const ext = extFromMime(mime);
  const base = cedula ? `${docType}_${cedula}` : `${docType}_user_${userId}`;
  return `${base}.${ext}`;
}

function assertDocType(docType) {
  if (!docType || !ALLOWED_DOC_TYPES.has(docType)) {
    const msg = `Tipo de documento no soportado: ${docType || ''}`;
    const err = new Error(msg);
    err.statusCode = 400;
    throw err;
  }
}

function assertFileAllowed(docType, file) {
  if (!file) {
    const err = new Error('Archivo requerido');
    err.statusCode = 400;
    throw err;
  }

  const isVideo = docType === 'videoAceptacion';
  const limit = isVideo ? DOC_LIMITS.videoBytes : DOC_LIMITS.defaultBytes;
  if (file.size > limit) {
    const err = new Error(
      `Archivo demasiado grande. Límite ${Math.round(limit / 1024 / 1024)}MB`,
    );
    err.statusCode = 413;
    throw err;
  }

  // Some clients omit the MIME type; treat as octet-stream and sniff later.
  const mime = (file.mimetype || 'application/octet-stream').toLowerCase();
  const allowed = ALLOWED_MIME[docType] || new Set();
  if (!allowed.has(mime)) {
    const err = new Error(
      `Formato no permitido (${mime || 'desconocido'}).`,
    );
    err.statusCode = 415;
    throw err;
  }
}

function bitsForDocFromCode(code, docType) {
  const idx = STATUS_DOC_ORDER.indexOf(docType);
  if (idx === -1) return 0;
  const shift = (STATUS_DOC_ORDER.length - 1 - idx) * 2;
  return (Number(code || 0) >> shift) & 0x3;
}

function inferVideoMimeFromFilename(name) {
  const ext = path.extname((name || '').toString()).toLowerCase();
  if (ext === '.mp4') return 'video/mp4';
  if (ext === '.mov') return 'video/quicktime';
  if (ext === '.m4v') return 'video/x-m4v';
  return null;
}

function ensureHasExtension(filename, contentType) {
  const safe = sanitizeFilename(filename);
  if (!safe) return safe;
  if (path.extname(safe)) return safe;
  const ext = extFromMime(contentType);
  if (!ext || ext === 'bin') return safe;
  return `${safe}.${ext}`;
}

async function normalizeUpload({ docType, file, userId }) {
  const inputMime = (file.mimetype || '').toLowerCase();
  const buf = file.buffer;

  if (docType === 'videoAceptacion') {
    const safeName = sanitizeFilename(file.originalname);
    const inferred = inferVideoMimeFromFilename(safeName);
    const contentType =
      inputMime && inputMime !== 'application/octet-stream'
        ? inputMime
        : (inferred || 'application/octet-stream');
    const rawFilename = safeName || fallbackName({ docType, userId, mime: contentType });
    const filename = ensureHasExtension(rawFilename, contentType);
    return {
      contentType,
      originalFilename: filename,
      byteSize: file.size,
      data: buf,
    };
  }

  // Non-video docs are always stored as PDF.
  let outBuf = null;
  if (bufferLooksLikePdf(buf)) {
    outBuf = buf;
  } else if (bufferLooksLikePng(buf) || bufferLooksLikeJpeg(buf) || inputMime.startsWith('image/')) {
    outBuf = await imageBufferToPdfBuffer(buf);
  } else {
    const err = new Error(`Formato no permitido (${inputMime || 'desconocido'}).`);
    err.statusCode = 415;
    throw err;
  }

  const filename = toPdfFilename(file.originalname, `${docType}_user_${userId}`);
  return {
    contentType: 'application/pdf',
    originalFilename: filename,
    byteSize: outBuf.length,
    data: outBuf,
  };
}

function setDocBitmaskToEnviado(prevCode, docType) {
  const n = STATUS_DOC_ORDER.length;
  const idx = STATUS_DOC_ORDER.indexOf(docType);
  if (idx === -1) return prevCode;
  const shift = (n - 1 - idx) * 2;
  // Clear the 2 bits then set to 01 (enviado)
  const cleared = prevCode & ~(0x3 << shift);
  return cleared | (0x1 << shift);
}

// Multer middleware (memory) used by route
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: DOC_LIMITS.videoBytes,
  },
});

exports.uploadMiddleware = upload.single('document');

exports.uploadUserDocument = async (req, res) => {
  try {
    const userId = req.user.id;
    const docType = req.params.docType;
    assertDocType(docType);

    // Business rule: if a document is already approved, prevent re-upload.
    // Admin can change the status back (e.g., pendiente/enviado) if a re-upload is required.
    try {
      const r = await db.query('SELECT document_status_code FROM users WHERE id = $1', [userId]);
      if (r.rows.length) {
        const bits = bitsForDocFromCode(r.rows[0].document_status_code, docType);
        if (bits === 3) {
          return res.status(409).json({
            ok: false,
            error:
              'Este documento ya fue aprobado y no puede ser reemplazado. Si necesitas actualizarlo, contacta al administrador.',
          });
        }
      }
    } catch (e) {
      // Non-blocking (avoid preventing uploads if this read fails)
      console.warn('[DOCS] No se pudo validar estado previo:', e.message);
    }

    const file = req.file;
    assertFileAllowed(docType, file);

    const normalized = await normalizeUpload({ docType, file, userId });
    const contentType = normalized.contentType;
    const originalFilename = sanitizeFilename(normalized.originalFilename);
    const byteSize = normalized.byteSize;
    const data = normalized.data;

    // Upsert document data
    await db.query(
      `INSERT INTO user_documents (user_id, doc_type, content_type, original_filename, byte_size, data)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (user_id, doc_type)
       DO UPDATE SET content_type = EXCLUDED.content_type,
                     original_filename = EXCLUDED.original_filename,
                     byte_size = EXCLUDED.byte_size,
                     data = EXCLUDED.data,
                     updated_at = NOW()`,
      [userId, docType, contentType, originalFilename || null, byteSize, data],
    );

    // Update document status bitmask + clear note for this docType
    try {
      const r = await db.query(
        'SELECT document_status_code, document_status_notes FROM users WHERE id = $1',
        [userId],
      );
      if (r.rows.length) {
        const prevCode = Number(r.rows[0].document_status_code) || 0;
        const newCode = setDocBitmaskToEnviado(prevCode, docType);
        await db.query(
          `UPDATE users
           SET document_status_code = $2,
               document_status_notes = COALESCE(document_status_notes, '{}'::jsonb) - $3
           WHERE id = $1`,
          [userId, newCode, docType],
        );
      }
    } catch (e) {
      // Non-blocking
      console.warn('[DOCS] No se pudo actualizar document_status_code:', e.message);
    }

    return res.json({ ok: true, doc_type: docType, byte_size: byteSize, content_type: contentType });
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ ok: false, error: e.message });
  }
};

async function fetchUserDocument({ userId, docType }) {
  const r = await db.query(
    'SELECT content_type, original_filename, byte_size, data, updated_at FROM user_documents WHERE user_id = $1 AND doc_type = $2',
    [userId, docType],
  );
  if (!r.rows.length) return null;
  return r.rows[0];
}

exports.listMyDocuments = async (req, res) => {
  try {
    const userId = req.user.id;
    const r = await db.query(
      `SELECT doc_type, content_type, original_filename, byte_size, updated_at
       FROM user_documents
       WHERE user_id = $1`,
      [userId],
    );

    const has = {};
    for (const t of ALLOWED_DOC_TYPES) has[t] = false;
    for (const row of r.rows) {
      if (row && row.doc_type && Object.prototype.hasOwnProperty.call(has, row.doc_type)) {
        has[row.doc_type] = true;
      }
    }

    return res.json({ ok: true, has, docs: r.rows });
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ ok: false, error: e.message });
  }
};

exports.getUserDocumentMeta = async (req, res) => {
  try {
    const userId = req.user.id;
    const docType = req.params.docType;
    assertDocType(docType);

    const doc = await fetchUserDocument({ userId, docType });
    if (!doc) return res.status(404).json({ ok: false, error: 'Documento no encontrado' });

    return res.json({
      ok: true,
      doc_type: docType,
      content_type: doc.content_type,
      original_filename: doc.original_filename,
      byte_size: doc.byte_size,
      updated_at: doc.updated_at,
    });
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ ok: false, error: e.message });
  }
};

exports.downloadUserDocument = async (req, res) => {
  try {
    const userId = req.user.id;
    const docType = req.params.docType;
    assertDocType(docType);

    const doc = await fetchUserDocument({ userId, docType });
    if (!doc) return res.status(404).json({ ok: false, error: 'Documento no encontrado' });

    const contentType = doc.content_type || 'application/octet-stream';
    const safeOriginal = sanitizeFilename(doc.original_filename);
    const filename = safeOriginal || fallbackName({ docType, userId, mime: contentType });

    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.status(200).send(doc.data);
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ ok: false, error: e.message });
  }
};

async function userIdFromCedula(cedulaRaw) {
  const cedula = normalizeCedula(cedulaRaw || '');
  if (!isValidCedula(cedula)) {
    const err = new Error('Cédula inválida (11 dígitos)');
    err.statusCode = 400;
    throw err;
  }
  const r = await db.query('SELECT id FROM users WHERE cedula = $1', [cedula]);
  if (!r.rows.length) {
    const err = new Error('Usuario no encontrado');
    err.statusCode = 404;
    throw err;
  }
  return { userId: r.rows[0].id, cedula };
}

exports.listUserDocumentsByCedula = async (req, res) => {
  try {
    const { userId, cedula } = await userIdFromCedula(req.query.cedula);

    const r = await db.query(
      `SELECT doc_type, content_type, original_filename, byte_size, updated_at
       FROM user_documents
       WHERE user_id = $1`,
      [userId],
    );

    const has = {};
    for (const t of ALLOWED_DOC_TYPES) has[t] = false;
    for (const row of r.rows) {
      if (row && row.doc_type && Object.prototype.hasOwnProperty.call(has, row.doc_type)) {
        has[row.doc_type] = true;
      }
    }

    return res.json({ ok: true, cedula, has, docs: r.rows });
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ ok: false, error: e.message });
  }
};

exports.getUserDocumentMetaByCedula = async (req, res) => {
  try {
    const docType = req.params.docType;
    assertDocType(docType);

    const { userId, cedula } = await userIdFromCedula(req.query.cedula);
    const doc = await fetchUserDocument({ userId, docType });
    if (!doc) return res.status(404).json({ ok: false, error: 'Documento no encontrado' });

    return res.json({
      ok: true,
      cedula,
      doc_type: docType,
      content_type: doc.content_type,
      original_filename: doc.original_filename,
      byte_size: doc.byte_size,
      updated_at: doc.updated_at,
    });
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ ok: false, error: e.message });
  }
};

exports.downloadUserDocumentByCedula = async (req, res) => {
  try {
    const docType = req.params.docType;
    assertDocType(docType);

    const { userId, cedula } = await userIdFromCedula(req.query.cedula);
    const doc = await fetchUserDocument({ userId, docType });
    if (!doc) return res.status(404).json({ ok: false, error: 'Documento no encontrado' });

    const contentType = doc.content_type || 'application/octet-stream';
    const safeOriginal = sanitizeFilename(doc.original_filename);
    const filename = safeOriginal || fallbackName({ docType, userId, mime: contentType, cedula });

    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    return res.status(200).send(doc.data);
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ ok: false, error: e.message });
  }
};
