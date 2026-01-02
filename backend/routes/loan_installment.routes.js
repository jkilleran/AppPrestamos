const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth.middleware');
const { uploadSingleSafe } = require('../controllers/upload.controller');
const { adminListActiveLoans, listInstallments, ensureInstallments, reportPaymentReceipt, adminUpdateInstallmentStatus, adminMarkOverdue, getLoanProgressController, downloadInstallmentReceipt } = require('../controllers/loan_installment.controller');

router.get('/admin/active', authMiddleware, adminListActiveLoans);
router.get('/:loanId', authMiddleware, listInstallments);
router.post('/:loanId/ensure', authMiddleware, ensureInstallments); // admin only inside controller
router.post('/installment/:installmentId/report', authMiddleware, uploadSingleSafe, reportPaymentReceipt);
// Endpoint para descargar/visualizar el recibo de una cuota
router.get('/installment/:installmentId/receipt', authMiddleware, downloadInstallmentReceipt);
router.put('/installment/:installmentId/status', authMiddleware, adminUpdateInstallmentStatus);
router.post('/admin/mark-overdue', authMiddleware, adminMarkOverdue);
router.get('/:loanId/progress', authMiddleware, getLoanProgressController);

module.exports = router;
