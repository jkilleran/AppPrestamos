const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth.middleware');
const { uploadSingle } = require('../controllers/upload.controller');
const { adminListActiveLoans, listInstallments, ensureInstallments, reportPaymentReceipt, adminUpdateInstallmentStatus, adminMarkOverdue, getLoanProgressController } = require('../controllers/loan_installment.controller');

router.get('/admin/active', authMiddleware, adminListActiveLoans);
router.get('/:loanId', authMiddleware, listInstallments);
router.post('/:loanId/ensure', authMiddleware, ensureInstallments); // admin only inside controller
router.post('/installment/:installmentId/report', authMiddleware, uploadSingle, reportPaymentReceipt);
router.put('/installment/:installmentId/status', authMiddleware, adminUpdateInstallmentStatus);
router.post('/admin/mark-overdue', authMiddleware, adminMarkOverdue);
router.get('/:loanId/progress', authMiddleware, getLoanProgressController);

module.exports = router;
