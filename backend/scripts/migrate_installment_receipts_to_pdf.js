/*
  Script de mantenimiento: normaliza recibos de cuotas a PDF.
  - Si receipt_file parece PDF, corrige receipt_mime/receipt_original_name.
  - Si receipt_file parece JPG/PNG (o receipt_mime image/*), convierte a PDF y actualiza.
  - Si el formato no es reconocible, lo deja intacto.

  Uso:
    cd backend
    node scripts/migrate_installment_receipts_to_pdf.js
*/

const PDFDocument = require('pdfkit');
const { PassThrough } = require('stream');
const pool = require('../db');

function sanitizePdfFilename(name, fallback) {
  const base = String(name || fallback || 'recibo.pdf')
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .replace(/_+/g, '_');
  return base.toLowerCase().endsWith('.pdf') ? base : `${base}.pdf`;
}

function bufferLooksLikePdf(buf) {
  if (!buf || !Buffer.isBuffer(buf)) return false;
  return buf.subarray(0, 5).toString('utf8') === '%PDF-';
}

function bufferLooksLikePng(buf) {
  if (!buf || !Buffer.isBuffer(buf) || buf.length < 8) return false;
  return (
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
  if (!buf || !Buffer.isBuffer(buf) || buf.length < 2) return false;
  return buf[0] === 0xff && buf[1] === 0xd8;
}

function imageBufferToPdfBuffer(imageBuffer) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ autoFirstPage: true });
      const out = new PassThrough();
      const chunks = [];

      out.on('data', (c) => chunks.push(c));
      out.on('end', () => resolve(Buffer.concat(chunks)));
      out.on('error', reject);

      doc.pipe(out);
      doc.image(imageBuffer, {
        fit: [520, 760],
        align: 'center',
        valign: 'center',
      });
      doc.end();
    } catch (e) {
      reject(e);
    }
  });
}

async function main() {
  const res = await pool.query(
    'SELECT id, installment_number, loan_request_id, receipt_file, receipt_mime, receipt_original_name FROM loan_installments WHERE receipt_file IS NOT NULL'
  );

  let updated = 0;
  let skipped = 0;

  for (const row of res.rows) {
    const id = row.id;
    const buf = row.receipt_file;
    const mime = String(row.receipt_mime || '').toLowerCase();

    const sniffPdf = bufferLooksLikePdf(buf);
    const sniffPng = bufferLooksLikePng(buf);
    const sniffJpeg = bufferLooksLikeJpeg(buf);
    const looksLikeImage = mime.startsWith('image/') || sniffPng || sniffJpeg;

    const filename = sanitizePdfFilename(
      row.receipt_original_name,
      `recibo_${id}.pdf`
    );

    try {
      if (sniffPdf || mime === 'application/pdf') {
        if (mime !== 'application/pdf' || (row.receipt_original_name && !String(row.receipt_original_name).toLowerCase().endsWith('.pdf'))) {
          await pool.query(
            'UPDATE loan_installments SET receipt_mime = $1, receipt_original_name = $2 WHERE id = $3',
            ['application/pdf', filename, id]
          );
          updated++;
        } else {
          skipped++;
        }
        continue;
      }

      if (looksLikeImage) {
        const pdfBuffer = await imageBufferToPdfBuffer(buf);
        await pool.query(
          'UPDATE loan_installments SET receipt_file = $1, receipt_mime = $2, receipt_original_name = $3 WHERE id = $4',
          [pdfBuffer, 'application/pdf', filename, id]
        );
        updated++;
        continue;
      }

      skipped++;
    } catch (e) {
      console.warn(`[MIGRATE] id=${id} fallo: ${e.message}`);
    }
  }

  console.log(`[MIGRATE] Updated: ${updated}, Skipped: ${skipped}, Total: ${res.rows.length}`);
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
