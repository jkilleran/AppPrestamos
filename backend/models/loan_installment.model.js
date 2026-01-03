const pool = require('../db');

/**
 * Obtiene cuotas de un préstamo.
 */
async function getInstallmentsByLoan(loanId) {
  const res = await pool.query(
    'SELECT * FROM loan_installments WHERE loan_request_id = $1 ORDER BY installment_number ASC',
    [loanId]
  );
  return res.rows;
}

/**
 * Dashboard admin: préstamos aprobados con agregados de cuotas.
 * (Agregación SQL para eficiencia)
 */
async function getActiveLoansWithAggregates() {
  const res = await pool.query(`
    SELECT lr.id as loan_id, lr.user_id, lr.amount, lr.months, lr.interest, lr.status,
           u.name as user_name, u.email as user_email, u.cedula as user_cedula,
           COUNT(i.*) as cuotas_total,
           SUM(CASE WHEN i.status = 'pagado' THEN 1 ELSE 0 END) as cuotas_pagadas,
           SUM(CASE WHEN i.status = 'reportado' THEN 1 ELSE 0 END) as cuotas_reportadas,
           COALESCE(SUM(i.total_due),0) as total_programado,
           COALESCE(SUM(i.paid_amount),0) as total_pagado
    FROM loan_requests lr
    JOIN users u ON u.id = lr.user_id
    LEFT JOIN loan_installments i ON i.loan_request_id = lr.id
    WHERE lr.status = 'aprobado'
    GROUP BY lr.id, u.id
    ORDER BY lr.created_at DESC;
  `);
  return res.rows;
}

/**
 * Genera cuotas (capital lineal + interés simple mensual) si aún no existen.
 * Coloca toda la lógica de negocio aquí (aplicación) en lugar de triggers SQL.
 */
async function createInstallmentsForLoan({ loanId, amount, months, annualInterestPct }) {
  const exists = await pool.query(
    'SELECT 1 FROM loan_installments WHERE loan_request_id = $1 LIMIT 1',
    [loanId]
  );
  if (exists.rowCount) return { skipped: true };
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const principal = Number(amount);
    const n = Number(months);
    if (!principal || !n) throw new Error('Monto o meses inválidos');
    const annual = Number(annualInterestPct) || 0;
    const monthlyRate = annual / 12 / 100; // asume anual. Ajustable si interest ya es mensual.
    let remaining = principal;
    const evenCapital = +(principal / n).toFixed(2);
    // Fecha base: momento de aprobación (now). Las cuotas serán cada 30 días fijos.
    const today = new Date();
    // Obtener categoría del usuario para aplicar "bonificación" (días de gracia) por categoría
    const catRes = await client.query('SELECT u.categoria FROM loan_requests lr JOIN users u ON u.id = lr.user_id WHERE lr.id = $1', [loanId]);
    const categoria = (catRes.rows[0]?.categoria || 'Hierro').toString().toLowerCase();
    const graceMap = {
      hierro: 0,
      plata: 2,
      oro: 3,
      platino: 4,
      diamante: 5,
      esmeralda: 7,
    };
    const graceDays = graceMap[categoria] ?? 0;
    for (let k = 1; k <= n; k++) {
      const interestPortion = +(remaining * monthlyRate).toFixed(2);
      const capitalPortion = k === n ? +remaining.toFixed(2) : evenCapital; // Última ajusta redondeo
      const total = +(capitalPortion + interestPortion).toFixed(2);
      // Intervalo fijo de 30 días (no meses calendario) => k * 30 días desde hoy
      const due = new Date(Date.UTC(
        today.getUTCFullYear(),
        today.getUTCMonth(),
        today.getUTCDate() + (k * 30)
      ));
      remaining = +(remaining - capitalPortion).toFixed(2);
      await client.query(
        `INSERT INTO loan_installments(
          loan_request_id, installment_number, due_date, capital, interest, total_due, grace_days
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [loanId, k, due.toISOString().slice(0, 10), capitalPortion, interestPortion, total, graceDays]
      );
    }
    await client.query('COMMIT');
    return { created: n };
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

/** Marca la cuota como que el usuario ha reportado (subió recibo) */
async function markInstallmentReported({ installmentId, userId, originalName, meta, fileBuffer, fileMime }) {
  const res = await pool.query(
    `UPDATE loan_installments
       SET status = 'reportado',
           reported_at = NOW(),
           receipt_original_name = $2,
           receipt_meta = $3,
           receipt_file = $4,
           receipt_mime = $5
     WHERE id = $1 RETURNING *`,
    [installmentId, originalName, meta ? JSON.stringify(meta) : null, fileBuffer, fileMime]
  );
  return res.rows[0];
}

/** Actualiza estado genérico de cuota */
async function updateInstallmentStatus({ installmentId, status, paidAmount }) {
  const fields = [];
  const params = [];
  let idx = 1;
  if (status) {
    fields.push(`status = $${idx++}`);
    params.push(status);
  }
  if (paidAmount != null) {
    fields.push(`paid_amount = $${idx++}`);
    params.push(paidAmount);
  }
  if (status === 'pagado') {
    fields.push('paid_at = NOW()');
  }
  params.push(installmentId);
  const res = await pool.query(
    `UPDATE loan_installments SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
    params
  );
  return res.rows[0];
}

/** Marca como pagada con paid_amount = total_due por defecto */
async function markInstallmentPaid(installmentId, paidAmount) {
  const row = await pool.query('SELECT total_due FROM loan_installments WHERE id = $1', [installmentId]);
  if (!row.rowCount) return null;
  const amount = paidAmount != null ? paidAmount : row.rows[0].total_due;
  const res = await pool.query(
    `UPDATE loan_installments SET status='pagado', paid_amount=$2, paid_at=NOW() WHERE id=$1 RETURNING *`,
    [installmentId, amount]
  );
  return res.rows[0];
}

/** Marca cuotas atrasadas (pendiente/reportado con due_date < hoy) */
async function markOverdueInstallments() {
  const res = await pool.query(
    `UPDATE loan_installments
       SET status = 'atrasado'
     WHERE status IN ('pendiente','reportado')
       AND (due_date + COALESCE(grace_days,0) * INTERVAL '1 day') < CURRENT_DATE
       AND status <> 'atrasado'`
  );
  return { updated: res.rowCount };
}

/** Progreso de un préstamo */
async function getLoanProgress(loanId) {
  const res = await pool.query(
    `SELECT COUNT(*) AS total,
            SUM(CASE WHEN status='pagado' THEN 1 ELSE 0 END) AS pagadas,
            SUM(CASE WHEN status='reportado' THEN 1 ELSE 0 END) AS reportadas,
            SUM(CASE WHEN status='pendiente' THEN 1 ELSE 0 END) AS pendientes,
            SUM(CASE WHEN status='atrasado' THEN 1 ELSE 0 END) AS atrasadas,
            COALESCE(SUM(total_due),0) AS total_programado,
            COALESCE(SUM(paid_amount),0) AS total_pagado
       FROM loan_installments WHERE loan_request_id = $1`,
    [loanId]
  );
  const r = res.rows[0] || {};
  const procent = r.total_programado > 0 ? Number((r.total_pagado / r.total_programado) * 100).toFixed(2) : '0';
  return {
    loan_id: loanId,
    cuotas_total: Number(r.total || 0),
    cuotas_pagadas: Number(r.pagadas || 0),
    cuotas_reportadas: Number(r.reportadas || 0),
    cuotas_pendientes: Number(r.pendientes || 0),
    cuotas_atrasadas: Number(r.atrasadas || 0),
    total_programado: Number(r.total_programado || 0),
    total_pagado: Number(r.total_pagado || 0),
    porcentaje_pagado: Number(procent)
  };
}

module.exports = {
  getInstallmentsByLoan,
  createInstallmentsForLoan,
  markInstallmentReported,
  updateInstallmentStatus,
  markInstallmentPaid,
  markOverdueInstallments,
  getLoanProgress,
  getActiveLoansWithAggregates,
};
