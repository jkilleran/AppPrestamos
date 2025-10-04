const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { findUserByEmail, createUser, updateUserPhoto, findUserById } = require('../models/user.model');
const { isValidCedula, normalizeCedula } = require('../utils/validation');
const path = require('path');

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

function logAuth(event, payload) {
  if (process.env.AUTH_DEBUG === '1') {
    try {
      console.log('[AUTH]', event, payload);
    } catch (_) {
      console.log('[AUTH]', event, '<<unserializable>>');
    }
  }
}

function sanitizeForLogUser(user = {}) {
  if (!user || typeof user !== 'object') return user;
  const { password, foto, token, ...rest } = user;
  return {
    ...rest,
    password: password ? '**hash**' : undefined,
    foto: foto ? `base64(${foto.length} chars)` : null,
    token: token ? token.slice(0, 12) + '…' : undefined,
  };
}

async function register(req, res) {
  logAuth('register:payload', sanitizeForLogUser(req.body));
  // Si viene archivo, obtener ruta relativa
  let foto = null;
  if (req.file) {
    foto = path.join('uploads/profiles', req.file.filename);
  }
  // Si el frontend envía JSON, usar req.body; si es multipart, los campos vienen en req.body
  let { email, password, name, role, cedula, telefono, domicilio, salario, categoria } = req.body;
  // Forzar valores por defecto si llegan vacíos o nulos
  domicilio = domicilio && domicilio.trim() ? domicilio : 'No especificado';
  salario = salario && salario !== '' ? Number(salario) : 0;
  // Validación de campos obligatorios
  if (!email || !password || !name || !cedula || !telefono || !domicilio || salario === null || salario === undefined) {
    return res.status(400).json({ error: 'Faltan campos obligatorios' });
  }
  // Validación de formato de email
  const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Correo inválido' });
  }
  // Normalizar y validar cédula (aceptar con o sin guiones; se almacenan solo dígitos)
  const cedulaNormalizada = normalizeCedula(cedula);
  if (!isValidCedula(cedulaNormalizada)) {
    return res.status(400).json({ error: 'Cédula inválida. Debe contener 11 dígitos (ej: 00112345671)' });
  }
  // Validación de teléfono (mantén el formato original, pero puedes normalizar si quieres)
  const telefonoRegex = /^\d{3}-\d{3}-\d{4}$/;
  if (!telefonoRegex.test(telefono)) {
    return res.status(400).json({ error: 'Teléfono inválido. Formato: xxx-xxx-xxxx' });
  }
  const hash = await bcrypt.hash(password, 10);
  try {
    await createUser({ email, password: hash, name, role, cedula: cedulaNormalizada, telefono, domicilio, salario, foto, categoria });
    logAuth('register:created', { email });
    res.json({ ok: true });
  } catch (e) {
    console.error('[AUTH][register] error:', e.message);
    res.status(400).json({ error: e.message || 'Usuario ya existe o datos inválidos' });
  }
}

async function login(req, res) {
  logAuth('login:payload', { email: req.body?.email });
  const { email, password } = req.body;
  const user = await findUserByEmail(email);
  logAuth('login:user', sanitizeForLogUser(user));
  if (!user) {
    logAuth('login:not_found', { email });
    return res.status(401).json({ error: 'Credenciales inválidas' });
  }
  const valid = await bcrypt.compare(password, user.password);
  logAuth('login:password_valid', { email, valid });
  if (!valid) {
    logAuth('login:invalid_password', { email });
    return res.status(401).json({ error: 'Credenciales inválidas' });
  }
  // Incluir email en el token para que endpoints autenticados puedan usarlo (p.ej., envío de documentos)
  const token = jwt.sign({ id: user.id, role: user.role, name: user.name, email: user.email }, JWT_SECRET, { expiresIn: '1d' });
  logAuth('login:token_generated', { email, token: token.slice(0, 12) + '…' });
  const includeFoto = process.env.AUTH_OMIT_FOTO === '1' ? false : true;
  res.json({
    token,
    role: user.role,
    name: user.name,
    email: user.email,
    cedula: user.cedula,
    telefono: user.telefono,
    domicilio: user.domicilio,
    salario: user.salario,
    foto: includeFoto ? (user.foto || null) : null, // base64 optionally omitted
    categoria: user.categoria || 'Hierro',
    prestamos_aprobados: user.prestamos_aprobados || 0
  });
}

async function uploadProfilePhoto(req, res) {
  try {
    if (!req.user || !req.user.id) {
      return res.status(401).json({ error: 'No autenticado' });
    }
    if (!req.file) {
      return res.status(400).json({ error: 'No se envió ninguna foto' });
    }
    // Convertir buffer a base64 (opcionalmente se puede omitir en respuesta por tamaño)
    const base64 = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;
    await updateUserPhoto(req.user.id, base64);
    logAuth('uploadProfilePhoto:updated', { userId: req.user.id, size: base64.length });
    const includeFoto = process.env.AUTH_OMIT_FOTO === '1' ? false : true;
    res.json({ ok: true, foto: includeFoto ? base64 : null });
  } catch (e) {
    console.error('[AUTH][uploadProfilePhoto] error:', e.message);
    res.status(500).json({ error: e.message || 'Error al actualizar la foto de perfil' });
  }
}

async function getProfile(req, res) {
  try {
    const user = await findUserById(req.user.id);
    if (!user) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json({
      ...user,
      categoria: user.categoria || 'Hierro',
      prestamos_aprobados: user.prestamos_aprobados || 0
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}

module.exports = { register, login, uploadProfilePhoto, getProfile };
