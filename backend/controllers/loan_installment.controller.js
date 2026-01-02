// Descargar el archivo de recibo asociado a una cuota
async function downloadInstallmentReceipt(req, res) {
  const { installmentId } = req.params;
  try {
    const result = await pool.query('SELECT receipt_file, receipt_mime, receipt_original_name FROM loan_installments WHERE id = $1', [installmentId]);
    if (!result.rows.length || !result.rows[0].receipt_file) {
      return res.status(404).json({ error: 'Archivo no encontrado para esta cuota' });
    }
    const row = result.rows[0];
    res.setHeader('Content-Type', row.receipt_mime || 'application/octet-stream');
    res.setHeader('Content-Disposition', `inline; filename="${row.receipt_original_name || 'recibo.pdf'}"`);
    res.send(row.receipt_file);
  } catch (e) {
    res.status(500).json({ error: 'Error recuperando archivo', details: e.message });
  }
}
const { getInstallmentsByLoan, createInstallmentsForLoan, markInstallmentReported, updateInstallmentStatus, getActiveLoansWithAggregates, markOverdueInstallments, getLoanProgress } = require('../models/loan_installment.model');
const { logInstallmentChange } = require('../models/loan_installment_log.model');
const pool = require('../db');
const { sendDocumentEmail, queueEmailSend, buildMailContext, buildMailPayload } = require('./upload.controller');

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
    const t0 = Date.now();
    console.log('[INSTALLMENT][REPORT] inicio installmentId=', installmentId, 'user=', req.user?.id);
    // Log request headers and body for debugging
    console.log('[INSTALLMENT][REPORT][DEBUG] headers:', req.headers);
    console.log('[INSTALLMENT][REPORT][DEBUG] body:', req.body);
    if (req.file) {
      console.log('[INSTALLMENT][REPORT][DEBUG] file info:', {
        originalname: req.file.originalname,
        mimetype: req.file.mimetype,
        size: req.file.size
      });
    } else {
      console.log('[INSTALLMENT][REPORT][DEBUG] file missing in request');
    }
    let phase = 'db_select_installment';
    const instRes = await pool.query('SELECT i.*, lr.user_id FROM loan_installments i JOIN loan_requests lr ON lr.id = i.loan_request_id WHERE i.id = $1', [installmentId]);
    console.log('[INSTALLMENT][REPORT][T+', Date.now()-t0,'ms] DB select installment OK');
    if (!instRes.rows.length) return res.status(404).json({ error: 'Cuota no encontrada' });
    const inst = instRes.rows[0];
    if (req.user.role !== 'admin' && inst.user_id !== req.user.id) return res.status(403).json({ error: 'No autorizado' });
    if (!req.file) {
      console.log('[INSTALLMENT][REPORT] falta archivo en request');
    } else {
      console.log('[INSTALLMENT][REPORT] archivo', { name: req.file.originalname, size: req.file.size, mime: req.file.mimetype });
    }
    // attach custom context for email
    req.body.type = `recibo_cuota_${inst.installment_number}_prestamo_${inst.loan_request_id}`;
    const asyncMode = process.env.EMAIL_ASYNC === '1';

    // --- Notificación a admins: recibo subido ---
    try {
      const { listAdmins } = require('../models/user.model');
      const { createNotification } = require('../models/notification.model');
      const { sendPushToUser } = require('../services/push');
      const admins = await listAdmins();
      const notifTitle = 'Nuevo recibo de cuota reportado';
      const notifBody = `El usuario ${req.user.name || req.user.email || req.user.id} reportó el pago de la cuota #${inst.installment_number} del préstamo #${inst.loan_request_id}.`;
      for (const admin of admins) {
        await createNotification(admin.id, {
          title: notifTitle,
          body: notifBody,
          data: { installmentId, userId: req.user.id, loanId: inst.loan_request_id }
        });
        await sendPushToUser({
          userId: admin.id,
          title: notifTitle,
          body: notifBody,
          data: { installmentId, userId: req.user.id, loanId: inst.loan_request_id }
        });
      }
    } catch (e) {
      console.warn('[NOTIFY][ADMIN][RECEIPT] Error notificando admins:', e.message);
    }
    // En modo asíncrono marcamos primero la cuota como reportada (optimista)
    if (asyncMode) {
      try {
        const updatedEarly = await markInstallmentReported({
          installmentId,
          userId: req.user.id,
          originalName: req.file?.originalname,
          meta: { userId: req.user.id, loanId: inst.loan_request_id, installment: inst.installment_number, async: true },
          fileBuffer: req.file?.buffer,
          fileMime: req.file?.mimetype
        });
        // Preparamos hook para devolver inmediatamente la cuota (se sobreescribe res.json para uniformidad)
        const original = res.json.bind(res);
        res.json = (payload) => {
          if (payload && payload.ok && !payload.installment) {
            payload.installment = updatedEarly;
          }
          return original(payload);
        };
      } catch (e) {
        console.error('[INSTALLMENT][REPORT][ASYNC] fallo marcado anticipado', e.message);
      }
    }
    // Wrap the original sendDocumentEmail but also mark in DB after success (solo modo sync)
    const originalJson = res.json.bind(res);
    res.json = async (payload) => {
      if (payload && payload.ok && !asyncMode) {
        try {
          console.log('[INSTALLMENT][REPORT] marcando cuota como reportada');
          const updated = await markInstallmentReported({
            installmentId,
            userId: req.user.id,
            originalName: req.file?.originalname,
            meta: { userId: req.user.id, loanId: inst.loan_request_id, installment: inst.installment_number },
            fileBuffer: req.file?.buffer,
            fileMime: req.file?.mimetype
          });
          console.log('[INSTALLMENT][REPORT] cuota marcada OK');
          // Adjuntar la cuota actualizada al payload para evitar un fetch adicional en el cliente
          payload.installment = updated;
        } catch (dbErr) {
          console.error('[INSTALLMENT][REPORT] error marcando reportado', dbErr.message);
          return originalJson({ ok: false, error: 'Marcado DB falló', details: dbErr.message });
        }
      }
      originalJson(payload);
    };
    if (asyncMode) {
      console.log('[INSTALLMENT][REPORT][ASYNC] encolando email y respondiendo rápido');
      try {
        const { user, docType, originalName, userEmail, emailRegex } = buildMailContext(req);
        // Reusar la lógica de settings ya dentro de sendDocumentEmail sería redundante; pedimos a sendDocumentEmail solo si necesitamos fallback.
        // Para simplicidad, llamamos a sendDocumentEmail que ya hace la encolada y respuesta.
        await sendDocumentEmail(req, res);
      } catch (e) {
        if (!res.headersSent) res.json({ ok: true, queued: true, warning: 'Fallo encolando email', detail: e.message });
      }
    } else {
      console.log('[INSTALLMENT][REPORT] enviando email...');
      phase = 'smtp_send';
      const beforeEmail = Date.now();
      await sendDocumentEmail(req, res);
      console.log('[INSTALLMENT][REPORT][T+', Date.now()-t0,'ms] sendDocumentEmail retornó (t envío=', Date.now()-beforeEmail,'ms )');
    }
  } catch (e) {
    console.error('[INSTALLMENT][REPORT] error general', e);
    // Log full error stack for debugging
    if (e && e.stack) {
      console.error('[INSTALLMENT][REPORT][DEBUG] error stack:', e.stack);
    }
    // Intentar diferenciar errores de SMTP vs validación archivo ya devueltos por sendDocumentEmail
    if (!res.headersSent) {
      res.status(500).json({ error: 'Error reportando pago', details: e.message, phase: 'unexpected', stack: e.stack });
    }
  }
}

async function adminUpdateInstallmentStatus(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { installmentId } = req.params;
  const { status, paid_amount } = req.body;
  try {
    const allowed = ['pendiente','reportado','pagado','rechazado','atrasado'];
    if (!status || !allowed.includes(String(status).toLowerCase())) {
      return res.status(400).json({ error: 'Estado inválido' });
    }
    // Obtener estado actual para validar transiciones sensibles
    const curRes = await pool.query('SELECT status, total_due FROM loan_installments WHERE id = $1', [installmentId]);
    if (!curRes.rowCount) return res.status(404).json({ error: 'Cuota no encontrada' });
    const currentStatus = curRes.rows[0].status;
    const desired = status.toLowerCase();
    // Reglas básicas:
    // - Solo se puede pasar a 'pagado' desde 'reportado'
    // - 'reportado' se puede desde pendiente, atrasado, rechazado
    // - 'rechazado' solo desde 'reportado'
    // - 'atrasado' lo gestiona proceso automático (permitimos manual pero solo desde pendiente o reportado)
    // - 'pendiente' se puede volver desde 'rechazado' o 'atrasado'
    let valid = true;
    if (desired === 'pagado' && currentStatus !== 'reportado') valid = false;
    if (desired === 'rechazado' && currentStatus !== 'reportado') valid = false;
    if (desired === 'reportado' && !['pendiente','atrasado','rechazado'].includes(currentStatus)) valid = false;
    if (desired === 'atrasado' && !['pendiente','reportado'].includes(currentStatus)) valid = false;
    if (desired === 'pendiente' && !['rechazado','atrasado'].includes(currentStatus)) valid = false;
    if (!valid) return res.status(400).json({ error: `Transición inválida de ${currentStatus} a ${desired}` });
    // Si se marca pagado y no se especifica paid_amount usar total_due
    let effectivePaid = paid_amount;
    if (desired === 'pagado' && (effectivePaid == null || effectivePaid === '')) {
      effectivePaid = curRes.rows[0].total_due;
    }
    const beforePaid = curRes.rows[0].paid_amount || null;
    const updated = await updateInstallmentStatus({ installmentId, status: desired, paidAmount: desired === 'pagado' ? effectivePaid : paid_amount });
    // Si se pagó, verificar si todas las cuotas del préstamo están pagadas para marcar préstamo liquidado
    if (desired === 'pagado' && updated && updated.loan_request_id) {
      try {
        const chk = await pool.query(
          `SELECT COUNT(*) FILTER (WHERE status != 'pagado') AS pendientes
             FROM loan_installments WHERE loan_request_id = $1`,
          [updated.loan_request_id]
        );
        const pendientes = Number(chk.rows[0]?.pendientes || 0);
        if (pendientes === 0) {
          await pool.query(
            `UPDATE loan_requests SET status = 'liquidado' WHERE id = $1 AND status != 'liquidado'`,
            [updated.loan_request_id]
          );
        }
      } catch (e) {
        console.warn('[LOAN] No se pudo marcar préstamo liquidado:', e.message);
      }
    }
    try {
      await logInstallmentChange({
        installmentId: Number(installmentId),
        oldStatus: currentStatus,
        newStatus: desired,
        adminId: req.user.id,
        paidBefore: beforePaid,
        paidAfter: updated?.paid_amount ?? null,
      });
    } catch (e) {
      console.warn('[LOG] No se pudo registrar cambio de cuota', e.message);
    }
    // --- Notificación a cliente: cuota aceptada/rechazada ---
    try {
      if (['pagado', 'rechazado'].includes(desired) && updated && updated.user_id) {
        const { findUserById } = require('../models/user.model');
        const { createNotification } = require('../models/notification.model');
        const { sendPushToUser } = require('../services/push');
        const client = await findUserById(updated.user_id);
        if (client) {
          const notifTitle = desired === 'pagado' ? 'Cuota aprobada' : 'Cuota rechazada';
          const notifBody = desired === 'pagado'
            ? `Tu comprobante de la cuota #${updated.installment_number} fue aprobado por el administrador.`
            : `Tu comprobante de la cuota #${updated.installment_number} fue rechazado por el administrador.`;
          await createNotification(client.id, {
            title: notifTitle,
            body: notifBody,
            data: { installmentId, loanId: updated.loan_request_id }
          });
          await sendPushToUser({
            userId: client.id,
            title: notifTitle,
            body: notifBody,
            data: { installmentId, loanId: updated.loan_request_id }
          });
        }
      }
    } catch (e) {
      console.warn('[NOTIFY][CLIENT][CUOTA] Error notificando cliente:', e.message);
    }
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

module.exports = { adminListActiveLoans, listInstallments, ensureInstallments, reportPaymentReceipt, adminUpdateInstallmentStatus, adminMarkOverdue, getLoanProgressController, downloadInstallmentReceipt };
