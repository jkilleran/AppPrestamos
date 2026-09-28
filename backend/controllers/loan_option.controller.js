const { getAllLoanOptions, createLoanOption, updateLoanOption, deleteLoanOption } = require('../models/loan_option.model');
const { findUserById } = require('../models/user.model');

const VALID_CATEGORIES = new Set(['hierro', 'plata', 'oro', 'platino', 'diamante', 'esmeralda']);
const CATEGORY_CANONICAL = {
  'hierro': 'Hierro',
  'plata': 'Plata',
  'oro': 'Oro',
  'platino': 'Platino',
  'diamante': 'Diamante',
  'esmeralda': 'Esmeralda'
};

const ERROR_INVALID = { error: 'Datos inválidos' };
const ERROR_AUTH = { error: 'No autorizado' };

function parseStrictNumber(value) {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (trimmed === '') {
    return null;
  }
  // Reject hex, exponent, trailing chars, multiple dots, bare decimals
  if (!/^\d+(\.\d+)?$/.test(trimmed)) {
    return null;
  }
  const num = Number(trimmed);
  return Number.isFinite(num) ? num : null;
}

function parseStrictPositiveInt(value) {
  if (typeof value === 'number') {
    return Number.isSafeInteger(value) && value > 0 ? value : null;
  }
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (trimmed === '' || !/^\d+$/.test(trimmed)) {
    return null;
  }
  const num = Number(trimmed);
  return Number.isSafeInteger(num) && num > 0 ? num : null;
}

function parseRouteId(value) {
  if (value === undefined || value === null) return null;
  return parseStrictPositiveInt(value);
}

function normalizeCategory(value) {
  if (value === null || value === undefined) {
    return 'Hierro';
  }
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  if (trimmed === '') {
    return 'Hierro';
  }
  const lower = trimmed.toLowerCase();
  return CATEGORY_CANONICAL[lower] || null;
}

function parseOptionalNumber(value) {
  if (value === null || value === undefined) {
    return null;
  }
  const parsed = parseStrictNumber(value);
  if (parsed === null) {
    return null;
  }
  if (parsed < 0) {
    return null;
  }
  return parsed;
}

async function getAllLoanOptionsController(req, res) {
  try {
    let salarioMinimo = null;
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

function validateLoanOptionPayload(body) {
  const { min_amount, max_amount, interest: interestRaw, months: monthsRaw, categoria_minima, ingreso_minimo } = body;

  const min = parseStrictNumber(min_amount);
  const max = parseStrictNumber(max_amount);
  const interest = parseStrictNumber(interestRaw);
  const months = parseStrictPositiveInt(monthsRaw);

  if (min === null || max === null || interest === null || months === null) {
    return null;
  }

  if (min < 0 || max <= 0 || max < min || interest < 0) {
    return null;
  }

  const categoria = normalizeCategory(categoria_minima);
  if (categoria === null) {
    return null;
  }

  const ingreso = parseOptionalNumber(ingreso_minimo);
  if (ingreso === null && ingreso_minimo !== undefined && ingreso_minimo !== null) {
    return null;
  }

  return {
    min_amount: min,
    max_amount: max,
    interest,
    months,
    categoria_minima: categoria,
    ingreso_minimo: ingreso
  };
}

async function createLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json(ERROR_AUTH);
  const validated = validateLoanOptionPayload(req.body);
  if (!validated) return res.status(400).json(ERROR_INVALID);
  try {
    const option = await createLoanOption(validated);
    res.status(201).json(option);
  } catch (e) {
    res.status(500).json({ error: 'Error interno' });
  }
}

async function updateLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json(ERROR_AUTH);
  const routeId = parseRouteId(req.params.id);
  if (routeId === null) return res.status(400).json(ERROR_INVALID);
  const validated = validateLoanOptionPayload(req.body);
  if (!validated) return res.status(400).json(ERROR_INVALID);
  try {
    const option = await updateLoanOption(routeId, validated);
    if (!option) return res.status(404).json({ error: 'Opción no encontrada' });
    res.json(option);
  } catch (e) {
    res.status(500).json({ error: 'Error interno' });
  }
}

async function deleteLoanOptionController(req, res) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json(ERROR_AUTH);
  const routeId = parseRouteId(req.params.id);
  if (routeId === null) return res.status(400).json(ERROR_INVALID);
  try {
    const result = await deleteLoanOption(routeId);
    if (!result) return res.status(404).json({ error: 'Opción no encontrada' });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Error interno' });
  }
}

module.exports = {
  getAllLoanOptionsController,
  createLoanOptionController,
  updateLoanOptionController,
  deleteLoanOptionController
};