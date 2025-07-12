const { createLoanRequest, getAllLoanRequests, updateLoanRequestStatus, getLoanRequestsByUser } = require('../models/loan_request.model');
const { incrementPrestamosAprobadosAndUpdateCategoria, findUserById } = require('../models/user.model');
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
  res.json(loans);
}

async function updateLoanRequestStatusController(req, res) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'No autorizado' });
  }
  const { id } = req.params;
  const { status } = req.body;
  if (!status) return res.status(400).json({ error: 'Falta el estado' });
  const updated = await updateLoanRequestStatus(id, status);
  // Si el préstamo fue aprobado (insensible a mayúsculas/minúsculas), incrementar contador y actualizar categoría
  if (updated && typeof updated.status === 'string' && updated.status.trim().toLowerCase() === 'aprobado') {
    await incrementPrestamosAprobadosAndUpdateCategoria(updated.user_id);
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
  getMyLoanRequestsController
};
