const { getInstallmentsByLoan, createInstallmentsForLoan, markInstallmentReported, updateInstallmentStatus, getActiveLoansWithAggregates, markOverdueInstallments, getLoanProgress } = require('../models/loan_installment.model');
const pool = require('../db');
const { sendDocumentEmail } = require('./upload.controller');

async function adminListActiveLoans(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  try {
    const rows = await getActiveLoansWithAggregates();
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: 'Error listando préstamos', details: e.message });
  }
}

async function listInstallments(req, res) {
  const { loanId } = req.params;
  try {
    const loanRes = await pool.query('SELECT * FROM loan_requests WHERE id = $1', [loanId]);
    if (!loanRes.rows.length) return res.status(404).json({ error: 'Préstamo no encontrado' });
    const loan = loanRes.rows[0];
    if (req.user.role !== 'admin' && loan.user_id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });
    const rows = await getInstallmentsByLoan(loanId);
    res.json({ loanId, installments: rows });
  } catch (e) {
    res.status(500).json({ error: 'Error obteniendo cuotas', details: e.message });
  }
}

// Auto-generate installments when an admin approves a loan (or through explicit endpoint).
async function ensureInstallments(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { loanId } = req.params;
  try {
    const loanRes = await pool.query('SELECT * FROM loan_requests WHERE id = $1', [loanId]);
    if (!loanRes.rows.length) return res.status(404).json({ error: 'Préstamo no encontrado' });
    const loan = loanRes.rows[0];
    if (loan.status !== 'aprobado') return res.status(400).json({ error: 'El préstamo aún no está aprobado' });
    const result = await createInstallmentsForLoan({ loanId, amount: loan.amount, months: loan.months, annualInterestPct: loan.interest });
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: 'Error generando cuotas', details: e.message });
  }
}

// User uploads a payment receipt for a specific installment; we reuse sendDocumentEmail logic.
async function reportPaymentReceipt(req, res) {
  const { installmentId } = req.params;
  try {
    const instRes = await pool.query('SELECT i.*, lr.user_id FROM loan_installments i JOIN loan_requests lr ON lr.id = i.loan_request_id WHERE i.id = $1', [installmentId]);
    if (!instRes.rows.length) return res.status(404).json({ error: 'Cuota no encontrada' });
    const inst = instRes.rows[0];
    if (req.user.role !== 'admin' && inst.user_id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });
    // attach custom context for email
    req.body.type = `recibo_cuota_${inst.installment_number}_prestamo_${inst.loan_request_id}`;
    // Wrap the original sendDocumentEmail but also mark in DB after success
    const originalJson = res.json.bind(res);
    res.json = async (payload) => {
      if (payload && payload.ok) {
        await markInstallmentReported({ installmentId, userId: req.user.id, originalName: req.file?.originalname, meta: { userId: req.user.id, loanId: inst.loan_request_id, installment: inst.installment_number } });
      }
      originalJson(payload);
    };
    await sendDocumentEmail(req, res);
  } catch (e) {
    res.status(500).json({ error: 'Error reportando pago', details: e.message });
  }
}

async function adminUpdateInstallmentStatus(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { installmentId } = req.params;
  const { status, paid_amount } = req.body;
  try {
    const updated = await updateInstallmentStatus({ installmentId, status, paidAmount: paid_amount });
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: 'Error actualizando cuota', details: e.message });
  }
}

async function adminMarkOverdue(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  try {
    const r = await markOverdueInstallments();
    res.json(r);
  } catch (e) {
    res.status(500).json({ error: 'Error marcando atrasadas', details: e.message });
  }
}

async function getLoanProgressController(req, res) {
  const { loanId } = req.params;
  try {
    const loanRes = await pool.query('SELECT * FROM loan_requests WHERE id=$1', [loanId]);
    if (!loanRes.rows.length) return res.status(404).json({ error: 'Préstamo no encontrado' });
    const loan = loanRes.rows[0];
    if (req.user.role !== 'admin' && loan.user_id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });
    const progress = await getLoanProgress(loanId);
    res.json(progress);
  } catch (e) {
    res.status(500).json({ error: 'Error obteniendo progreso', details: e.message });
  }
}

module.exports = { adminListActiveLoans, listInstallments, ensureInstallments, reportPaymentReceipt, adminUpdateInstallmentStatus, adminMarkOverdue, getLoanProgressController };
