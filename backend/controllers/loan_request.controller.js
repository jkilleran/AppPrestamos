const { createLoanRequest, getAllLoanRequests, updateLoanRequestStatus, getLoanRequestsByUser } = require('../models/loan_request.model');
const { incrementPrestamosAprobadosAndUpdateCategoria } = require('../models/user.model');

async function createLoanRequestController(req, res) {
  const { amount, months, interest, purpose } = req.body;
  const userId = req.user.id;
  const userName = req.user.name;
  if (!amount || !months || !interest || !purpose) {
    return res.status(400).json({ error: 'Faltan datos' });
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
