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
  // Si existe firma, reflejar estado "firmado" si aún estaba pendiente
  const effectiveStatus = (loan.signature_data && (!loan.status || loan.status === 'pendiente')) ? 'firmado' : loan.status;
  doc.text(`Estado: ${effectiveStatus}`);
    doc.moveDown();
    if (loan.signature_data) {
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
    } else {
      doc.text('Aún no firmada.');
    }
    doc.end();
  } catch (e) {
    res.status(500).json({ error: 'Error generando PDF', details: e.message });
  }
});

module.exports = router;
