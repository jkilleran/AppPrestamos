const { createLoanRequest, getAllLoanRequests, updateLoanRequestStatus, getLoanRequestsByUser, signLoanRequest } = require('../models/loan_request.model');
const { findUserById, incrementPrestamosAprobadosAndUpdateCategoria } = require('../models/user.model');
const { createInstallmentsForLoan } = require('../models/loan_installment.model');
const { notifyLoanStatusChange } = require('../services/notifier');
const { sendPushToUser } = require('../services/push');
const { createNotification } = require('../models/notification.model');
const pool = require('../db');

const LOAN_STATUSES = new Set(['pendiente', 'aprobado', 'rechazado', 'liquidado']);
const LOAN_TRANSITIONS = {
  pendiente: new Set(['aprobado', 'rechazado']),
  rechazado: new Set(['pendiente']),
  aprobado: new Set(['liquidado']),
  liquidado: new Set(),
};

async function createLoanRequestController(req, res) {
  const { amount, purpose, loan_option_id } = req.body;
  const userId = req.user.id;

  if (typeof loan_option_id !== 'number' && typeof loan_option_id !== 'string') {
    return res.status(400).json({ error: 'loan_option_id inválido' });
  }
  if (typeof loan_option_id === 'number') {
    if (!Number.isSafeInteger(loan_option_id) || loan_option_id <= 0) {
      return res.status(400).json({ error: 'loan_option_id inválido' });
    }
  } else {
    if (!/^\d+$/.test(loan_option_id)) {
      return res.status(400).json({ error: 'loan_option_id inválido' });
    }
  }
  const loanOptionId = Number(loan_option_id);

  let validatedAmount;
  if (typeof amount === 'number') {
    if (!Number.isFinite(amount) || amount <= 0) return res.status(400).json({ error: 'amount inválido' });
    validatedAmount = amount;
  } else if (typeof amount === 'string') {
    const t = amount.trim();
    if (!/^\d+(?:\.\d+)?$/.test(t)) return res.status(400).json({ error: 'amount inválido' });
    const p = Number(t);
    if (!Number.isFinite(p) || p <= 0) return res.status(400).json({ error: 'amount inválido' });
    validatedAmount = p;
  } else {
    return res.status(400).json({ error: 'amount inválido' });
  }

  let trimmedPurpose;
  if (typeof purpose !== 'string') return res.status(400).json({ error: 'purpose inválido' });
  trimmedPurpose = purpose.trim();
  if (trimmedPurpose === '') return res.status(400).json({ error: 'purpose inválido' });

  let option;
  try {
    const r = await pool.query('SELECT * FROM loan_options WHERE id = $1', [loanOptionId]);
    if (!r.rows || r.rows.length === 0) return res.status(400).json({ error: 'Opción no encontrada' });
    option = r.rows[0];
  } catch (e) {
    return res.status(500).json({ error: 'Error al obtener opción' });
  }
  if (!option || typeof option !== 'object') return res.status(500).json({ error: 'Configuración inválida' });

  const normNum = (v, allowNull = false) => {
    if (allowNull && (v === null || v === undefined)) return { ok: true, val: null };
    if (typeof v === 'number') return Number.isFinite(v) ? { ok: true, val: v } : { ok: false };
    if (typeof v !== 'string') return { ok: false };
    const s = v.trim();
    if (!s || !/^-?(?:\d+)(?:\.\d+)?$/.test(s)) return { ok: false };
    const n = Number(s);
    return Number.isFinite(n) ? { ok: true, val: n } : { ok: false };
  };

  const minRes = normNum(option.min_amount);
  const maxRes = normNum(option.max_amount);
  const intRes = normNum(option.interest);
  const monRes = normNum(option.months);
  const ingRes = normNum(option.ingreso_minimo, true);
  if (!minRes.ok || !maxRes.ok || !intRes.ok || !monRes.ok || !ingRes.ok) {
    return res.status(500).json({ error: 'Configuración de opción inválida' });
  }
  const optMin = minRes.val, optMax = maxRes.val, optInt = intRes.val, optMon = monRes.val;
  const rawIngres = ingRes.val, hasIng = rawIngres !== null && rawIngres !== undefined;

  if (optMin < 0 || optMax <= 0 || optMax < optMin) return res.status(500).json({ error: 'Configuración inválida' });
  if (optInt < 0) return res.status(500).json({ error: 'Configuración inválida' });
  if (!Number.isSafeInteger(optMon) || optMon <= 0) return res.status(500).json({ error: 'Configuración inválida' });

  if (validatedAmount < optMin || validatedAmount > optMax) return res.status(400).json({ error: 'Monto fuera de rango' });

  let user;
  try {
    user = await findUserById(userId);
    if (!user) return res.status(404).json({ error: 'Usuario no encontrado' });
  } catch (e) {
    return res.status(500).json({ error: 'Error al obtener usuario' });
  }

  const cats = ['hierro','plata','oro','platino','diamante','esmeralda'];
  const normCat = (val, badStatus) => {
    if (val === null || val === undefined) return { ok: true, idx: 0, name: 'hierro' };
    if (typeof val !== 'string') return { ok: false, status: badStatus };
    const n = val.trim().toLowerCase();
    if (n === '') return { ok: true, idx: 0, name: 'hierro' };
    const idx = cats.indexOf(n);
    if (idx < 0) return { ok: false, status: badStatus };
    return { ok: true, idx, name: n };
  };
  const uCat = normCat(user.categoria, 403);
  if (!uCat.ok) return res.status(403).json({ error: 'Categoría desconocida' });
  const oCat = normCat(option.categoria_minima, 500);
  if (!oCat.ok) return res.status(500).json({ error: 'Categoría de opción desconocida' });
  if (uCat.idx < oCat.idx) return res.status(403).json({ error: 'Categoría insuficiente' });

  if (hasIng) {
    let sal = null;
    if (typeof user.salario === 'number') {
      sal = Number.isFinite(user.salario) ? user.salario : null;
    } else if (typeof user.salario === 'string') {
      const ts = user.salario.trim();
      if (!/^-?(?:\d+)(?:\.\d+)?$/.test(ts)) sal = null;
      else { sal = Number(ts); if (!Number.isFinite(sal)) sal = null; }
    }
    if (sal === null || sal < 0 || sal < rawIngres) return res.status(403).json({ error: 'Salario inválido' });
  }

  try {
    const loan = await createLoanRequest({ userId, userName: user.name, amount: validatedAmount, months: optMon, interest: optInt, purpose: trimmedPurpose });
    res.status(201).json(loan);
  } catch (e) {
    res.status(500).json({ error: 'Error al crear solicitud' });
  }
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
  const loanId = Number(req.params.id);
  if (!Number.isSafeInteger(loanId) || loanId <= 0) {
    return res.status(400).json({ error: 'Identificador de solicitud inválido' });
  }

  const targetStatus = String(req.body?.status || '').trim().toLowerCase();
  if (!LOAN_STATUSES.has(targetStatus)) {
    return res.status(400).json({ error: 'Estado inválido' });
  }

  console.log('[LOAN_STATUS] Admin', req.user.id, 'cambia solicitud', loanId, '->', targetStatus);

  try {
    const currentResult = await pool.query('SELECT * FROM loan_requests WHERE id = $1', [loanId]);
    if (!currentResult.rows.length) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const existing = currentResult.rows[0];
    const currentStatus = String(existing.status || '').trim().toLowerCase();
    if (!LOAN_STATUSES.has(currentStatus)) {
      return res.status(409).json({ error: 'La solicitud tiene un estado actual no reconocido' });
    }

    // Repeated requests are successful no-ops: no counter, installments, or
    // notifications are produced a second time.
    if (currentStatus === targetStatus) {
      return res.json({ ok: true, loan: existing, unchanged: true });
    }

    if (!LOAN_TRANSITIONS[currentStatus].has(targetStatus)) {
      return res.status(409).json({
        error: `Transición inválida de ${currentStatus} a ${targetStatus}`,
      });
    }

    // Compare-and-set makes concurrent approvals idempotent. Only one request
    // can transition the row from the observed state and earn the side effects.
    const updated = await updateLoanRequestStatus(loanId, targetStatus, existing.status);
    if (!updated) {
      const racedResult = await pool.query('SELECT * FROM loan_requests WHERE id = $1', [loanId]);
      const racedLoan = racedResult.rows[0];
      if (racedLoan && String(racedLoan.status).trim().toLowerCase() === targetStatus) {
        return res.json({ ok: true, loan: racedLoan, unchanged: true });
      }
      return res.status(409).json({ error: 'La solicitud cambió mientras se procesaba la actualización' });
    }

    if (targetStatus === 'aprobado') {
      try {
        await incrementPrestamosAprobadosAndUpdateCategoria(updated.user_id);
      } catch (e) {
        console.warn('[LOAN] Error incrementando categoría:', e.message);
      }
      try {
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

    return res.json({ ok: true, loan: updated });
  } catch (e) {
    console.error('[LOAN_STATUS] Error actualizando solicitud:', e.message);
    return res.status(500).json({ error: 'Error actualizando solicitud' });
  }
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