const { createLoanRequest, getAllLoanRequests, updateLoanRequestStatus, getLoanRequestsByUser, signLoanRequest } = require('../models/loan_request.model');
const { createInstallmentsForLoan } = require('../models/loan_installment.model');
const { incrementPrestamosAprobadosAndUpdateCategoria, findUserById } = require('../models/user.model');
const { notifyLoanStatusChange } = require('../services/notifier');
const { sendPushToUser } = require('../services/push');
const { createNotification } = require('../models/notification.model');
const pool = require('../db');

async function createLoanRequestController(req, res) {
  const { amount, months, interest, purpose, loan_option_id } = req.body;
  const userId = req.user.id;
  const userName = req.user.name;
  if (!amount || !months || !interest || !purpose || !loan_option_id) {
    return res.status(400).json({ error: 'Faltan datos' });
  }
  // Validar categoría mínima
  try {
    // Obtener la opción de préstamo seleccionada
    const optionRes = await pool.query('SELECT categoria_minima FROM loan_options WHERE id = $1', [loan_option_id]);
    if (!optionRes.rows.length) {
      return res.status(400).json({ error: 'Opción de préstamo no encontrada' });
    }
    const categoriaMinima = optionRes.rows[0].categoria_minima;
    // Obtener la categoría del usuario
    const user = await findUserById(userId);
    const categorias = ['Hierro', 'Plata', 'Oro', 'Platino', 'Diamante', 'Esmeralda'];
    const userCatIndex = categorias.findIndex(c => c.toLowerCase() === (user.categoria || 'Hierro').toLowerCase());
    const minCatIndex = categorias.findIndex(c => c.toLowerCase() === (categoriaMinima || 'Hierro').toLowerCase());
    if (userCatIndex < minCatIndex) {
      return res.status(403).json({ error: `Tu categoría actual (${user.categoria}) no cumple con la categoría mínima (${categoriaMinima}) para este préstamo.` });
    }
  } catch (err) {
    return res.status(500).json({ error: 'Error validando categoría mínima', details: err.message });
  }
  const loan = await createLoanRequest({ userId, userName, amount, months, interest, purpose });
  res.status(201).json(loan);
}

async function getAllLoanRequestsController(req, res) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'No autorizado' });
  }
  const loans = await getAllLoanRequests();
  // Mapear campo firmado
  const mapped = loans.map(l => {
  const firmado = (l.signature_status === 'firmada') || !!(l.signed_at);
    return {
      ...l,
      firmado,
    };
  });
  res.json(mapped);
}

async function updateLoanRequestStatusController(req, res) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'No autorizado' });
  }
  const { id } = req.params;
  const { status } = req.body;
  if (!status) return res.status(400).json({ error: 'Falta el estado' });
  // Leer estado actual antes de mutar (evita dejar estado 'aprobado' inválido si falta firma)
  let existing;
  try {
    const r = await pool.query('SELECT * FROM loan_requests WHERE id=$1', [id]);
    if (!r.rows.length) return res.status(404).json({ error: 'Solicitud no encontrada' });
    existing = r.rows[0];
  } catch (e) {
    return res.status(500).json({ error: 'Error consultando solicitud', details: e.message });
  }

  const targetStatus = String(status).trim().toLowerCase();
  if (targetStatus === 'aprobado') {
    // Criterio de firma alineado con frontend: signature_status='firmada' OR signed_at OR signature_data no vacía
    const hasSignature = (existing.signature_status === 'firmada') || !!existing.signed_at || (existing.signature_data && String(existing.signature_data).trim().length > 0);
    if (!hasSignature) {
      return res.status(400).json({ error: 'La solicitud aún no tiene firma electrónica registrada.' });
    }
  }

  // Actualizar estado ahora que pasó validaciones
  const updated = await updateLoanRequestStatus(id, status);

  if (updated && targetStatus === 'aprobado') {
    try {
      // 1. Incrementar categoría/contador
      await incrementPrestamosAprobadosAndUpdateCategoria(updated.user_id);
    } catch (e) {
      console.warn('[LOAN] Error incrementando categoría:', e.message);
    }
    try {
      // 2. Generar cuotas (idempotente)
      await createInstallmentsForLoan({
        loanId: updated.id,
        amount: updated.amount,
        months: updated.months,
        annualInterestPct: updated.interest,
      });
    } catch (e) {
      console.warn('[LOAN] Error creando cuotas automáticamente:', e.message);
    }
  }
  try {
    const user = await findUserById(updated.user_id);
    await notifyLoanStatusChange({ user, loan: updated, newStatus: updated.status });
    await createNotification(updated.user_id, {
      title: 'Tu solicitud cambió de estado',
      body: `Nuevo estado: ${updated.status}`,
      data: { type: 'loan_status', loanId: updated.id, status: updated.status },
    });
    await sendPushToUser({
      userId: updated.user_id,
      title: 'Tu solicitud cambió de estado',
      body: `Nuevo estado: ${updated.status}`,
      data: { type: 'loan_status', loanId: String(updated.id || ''), status: String(updated.status || '') },
    });
  } catch (e) {
    console.warn('notifyLoanStatusChange fallo:', e.message);
  }
  res.json(updated);
}

async function getMyLoanRequestsController(req, res) {
  const userId = req.user.id;
  const loans = await getLoanRequestsByUser(userId);
  res.json(loans);
}

module.exports = {
  createLoanRequestController,
  getAllLoanRequestsController,
  updateLoanRequestStatusController,
  getMyLoanRequestsController,
  signLoanRequestController
};

async function signLoanRequestController(req, res) {
  const { id } = req.params;
  const { signature, mode } = req.body;
  if (!signature) return res.status(400).json({ error: 'Falta la firma' });
  try {
    const updated = await signLoanRequest(id, req.user.id, signature, mode);
    if (!updated) return res.status(404).json({ error: 'Solicitud no encontrada' });
    await createNotification(req.user.id, {
      title: 'Firma registrada',
      body: `Has firmado la solicitud #${id}`,
      data: { type: 'loan_signature', loanId: id },
    });
    await sendPushToUser({
      userId: req.user.id,
      title: 'Firma registrada',
      body: `Firma electrónica aplicada a tu solicitud #${id}`,
      data: { type: 'loan_signature', loanId: String(id) },
    });
  res.json({ success: true, loan: updated });
  } catch (e) {
    res.status(500).json({ error: 'Error registrando firma', details: e.message });
  }
}
