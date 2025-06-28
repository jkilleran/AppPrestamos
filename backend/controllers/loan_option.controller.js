const { getAllLoanOptions, createLoanOption, updateLoanOption, deleteLoanOption } = require('../models/loan_option.model');

async function getAllLoanOptionsController(req, res) {
  // Permitir acceso a cualquier usuario autenticado o público
  const options = await getAllLoanOptions();
  res.json(options);
}

async function createLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { min_amount, max_amount, interest, months } = req.body;
  if (!min_amount || !max_amount || !interest || !months) return res.status(400).json({ error: 'Faltan datos' });
  const option = await createLoanOption({ min_amount, max_amount, interest, months });
  res.status(201).json(option);
}

async function updateLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { id } = req.params;
  const { min_amount, max_amount, interest, months } = req.body;
  if (!min_amount || !max_amount || !interest || !months) return res.status(400).json({ error: 'Faltan datos' });
  const option = await updateLoanOption(id, { min_amount, max_amount, interest, months });
  res.json(option);
}

async function deleteLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { id } = req.params;
  await deleteLoanOption(id);
  res.json({ success: true });
}

module.exports = {
  getAllLoanOptionsController,
  createLoanOptionController,
  updateLoanOptionController,
  deleteLoanOptionController
};
