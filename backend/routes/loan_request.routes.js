const express = require('express');
const { authMiddleware } = require('../middleware/auth.middleware');
const {
  createLoanRequestController,
  getAllLoanRequestsController,
  updateLoanRequestStatusController,
  getMyLoanRequestsController,
  signLoanRequestController
} = require('../controllers/loan_request.controller');

const router = express.Router();

router.post('/', authMiddleware, createLoanRequestController);
router.get('/', authMiddleware, getAllLoanRequestsController);
router.get('/mine', authMiddleware, getMyLoanRequestsController);
router.put('/:id/status', authMiddleware, updateLoanRequestStatusController);
router.post('/:id/sign', authMiddleware, signLoanRequestController);
// PDF con firma: solo admin o dueño
const pool = require('../db');
const PDFDocument = require('pdfkit');
router.get('/:id/pdf', authMiddleware, async (req, res) => {
  const { id } = req.params;
  try {
    const qr = await pool.query('SELECT lr.*, u.name as user_name, u.email as user_email FROM loan_requests lr JOIN users u ON lr.user_id = u.id WHERE lr.id=$1', [id]);
    if (!qr.rows.length) return res.status(404).json({ error: 'No encontrado' });
    const loan = qr.rows[0];
    if (req.user.role !== 'admin' && req.user.id !== loan.user_id) {
      return res.status(403).json({ error: 'No autorizado' });
    }
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=prestamo_${id}.pdf`);
    const doc = new PDFDocument({ margin: 50 });
    doc.pipe(res);
    doc.fontSize(18).text('Solicitud de Préstamo', { align: 'center' });
    doc.moveDown();
    doc.fontSize(12).text(`ID: ${loan.id}`);
    doc.text(`Usuario: ${loan.user_name} (${loan.user_email})`);
    doc.text(`Monto: ${loan.amount}`);
    doc.text(`Meses: ${loan.months}`);
    doc.text(`Interés: ${loan.interest}%`);
    doc.text(`Propósito: ${loan.purpose}`);
  // Si existe firma (imagen) o al menos fecha de firma, reflejar estado "firmado" si aún estaba pendiente
  const hasSigImage = !!(loan.signature_data && String(loan.signature_data).trim().length > 0);
  const hasSignedAt = !!loan.signed_at;
  const effectiveStatus = ((hasSigImage || hasSignedAt) && (!loan.status || loan.status === 'pendiente')) ? 'firmado' : loan.status;
  doc.text(`Estado: ${effectiveStatus}`);
    doc.moveDown();
  if (hasSigImage) {
      doc.text('Firma electrónica:');
      try {
        let raw = loan.signature_data.trim();
        // El frontend puede enviar data URI ("data:image/png;base64,....") o solo base64
        const commaIdx = raw.indexOf(',');
        if (raw.startsWith('data:') && commaIdx !== -1) {
          raw = raw.substring(commaIdx + 1); // eliminar metadata
        }
        const buf = Buffer.from(raw, 'base64');
        doc.image(buf, { fit: [300, 120] });
      } catch (e) {
        doc.fillColor('red').text('Error renderizando firma');
        doc.fillColor('black');
      }
      doc.moveDown();
      doc.text(`Firmado en: ${loan.signed_at || ''}`);
      if (loan.signature_mode) {
        doc.text(`Modo de firma: ${loan.signature_mode === 'typed' ? 'Escrita (texto)' : loan.signature_mode === 'drawn' ? 'Dibujada' : loan.signature_mode}`);
      }
    } else if (hasSignedAt) {
      // Sin imagen, pero se registró fecha de firma -> consideramos firmada y mostramos metadatos
      doc.text('Firma electrónica: registrada (sin imagen)');
      doc.moveDown();
      doc.text(`Firmado en: ${loan.signed_at}`);
      if (loan.signature_mode) {
        doc.text(`Modo de firma: ${loan.signature_mode === 'typed' ? 'Escrita (texto)' : loan.signature_mode === 'drawn' ? 'Dibujada' : loan.signature_mode}`);
      }
    } else {
      doc.text('Aún no firmada.');
    }
    doc.end();
  } catch (e) {
    res.status(500).json({ error: 'Error generando PDF', details: e.message });
  }
});

module.exports = router;
