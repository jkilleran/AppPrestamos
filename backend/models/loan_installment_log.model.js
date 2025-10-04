const pool = require('../db');

async function logInstallmentChange({ installmentId, oldStatus, newStatus, adminId, paidBefore, paidAfter }) {
  await pool.query(
    `INSERT INTO loan_installment_logs(installment_id, old_status, new_status, admin_id, paid_amount_before, paid_amount_after)
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [installmentId, oldStatus, newStatus, adminId, paidBefore, paidAfter]
  );
}

async function getInstallmentLogs(installmentId) {
  const r = await pool.query(
    `SELECT l.*, u.name as admin_name FROM loan_installment_logs l
      LEFT JOIN users u ON u.id = l.admin_id
     WHERE installment_id = $1 ORDER BY l.id DESC`,
    [installmentId]
  );
  return r.rows;
}

module.exports = { logInstallmentChange, getInstallmentLogs };
