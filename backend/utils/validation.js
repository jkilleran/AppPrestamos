// Utilidades de validación y normalización de cédula
// Formato esperado final almacenado: solo 11 dígitos
const CEDULA_REGEX = /^[0-9]{11}$/;

function normalizeCedula(cedula) {
  if (typeof cedula !== 'string') return '';
  // Eliminar todo lo que no sea dígito
  return cedula.replace(/\D/g, '');
}

function isValidCedula(cedula) {
  const norm = normalizeCedula(cedula);
  return CEDULA_REGEX.test(norm);
}

module.exports = { isValidCedula, normalizeCedula };
