const { getAllLoanOptions, createLoanOption, updateLoanOption, deleteLoanOption } = require('../models/loan_option.model');
const { findUserById } = require('../models/user.model');

async function getAllLoanOptionsController(req, res) {
  try {
    let salarioMinimo = null;
    // Si hay usuario y no es admin, filtrar por su salario
    if (req.user && req.user.id && req.user.role !== 'admin') {
      const user = await findUserById(req.user.id);
      if (user && user.salario != null) salarioMinimo = Number(user.salario);
    }
    const options = await getAllLoanOptions({ salarioMinimo });
    res.json(options);
  } catch (e) {
    res.status(500).json({ error: e.message || 'Error al obtener opciones' });
  }
}

async function createLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { min_amount, max_amount, interest, months, categoria_minima, ingreso_minimo } = req.body;
  if (min_amount == null || max_amount == null || interest == null || months == null) {
    return res.status(400).json({ error: 'Faltan datos' });
  }
  const option = await createLoanOption({ min_amount, max_amount, interest, months, categoria_minima, ingreso_minimo });
  res.status(201).json(option);
}

async function updateLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  const { id } = req.params;
  const { min_amount, max_amount, interest, months, categoria_minima, ingreso_minimo } = req.body;
  if (min_amount == null || max_amount == null || interest == null || months == null) {
    return res.status(400).json({ error: 'Faltan datos' });
  }
  const option = await updateLoanOption(id, { min_amount, max_amount, interest, months, categoria_minima, ingreso_minimo });
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
