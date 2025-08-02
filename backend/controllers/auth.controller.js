const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { findUserByEmail, createUser, updateUserPhoto, findUserById } = require('../models/user.model');
const path = require('path');

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

async function register(req, res) {
  console.log('Datos recibidos en registro:', req.body); // <-- Log para depuración
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
  // Validación de cédula y teléfono
  const cedulaRegex = /^\d{3}-\d{7}-\d{1}$/;
  const telefonoRegex = /^\d{3}-\d{3}-\d{4}$/;
  if (!cedulaRegex.test(cedula)) {
    return res.status(400).json({ error: 'Cédula inválida. Formato: xxx-xxxxxxx-x' });
  }
  if (!telefonoRegex.test(telefono)) {
    return res.status(400).json({ error: 'Teléfono inválido. Formato: xxx-xxx-xxxx' });
  }
  const hash = await bcrypt.hash(password, 10);
  try {
    await createUser({ email, password: hash, name, role, cedula, telefono, domicilio, salario, foto, categoria });
    res.json({ ok: true });
  } catch (e) {
    console.error(e); // Log del error real
    res.status(400).json({ error: 'Usuario ya existe o datos inválidos' });
  }
}

async function login(req, res) {
  console.log('LOGIN - Datos recibidos:', req.body);
  const { email, password } = req.body;
  const user = await findUserByEmail(email);
  console.log('LOGIN - Usuario encontrado:', user);
  if (!user) {
    console.log('LOGIN - Usuario no encontrado para email:', email);
    return res.status(401).json({ error: 'Credenciales inválidas' });
  }
  const valid = await bcrypt.compare(password, user.password);
  console.log('LOGIN - Password válido:', valid);
  if (!valid) {
    console.log('LOGIN - Contraseña incorrecta para email:', email);
    return res.status(401).json({ error: 'Credenciales inválidas' });
  }
  const token = jwt.sign({ id: user.id, role: user.role, name: user.name }, JWT_SECRET, { expiresIn: '1d' });
  console.log('LOGIN - Token generado:', token);
  res.json({
    token,
    role: user.role,
    name: user.name,
    email: user.email,
    cedula: user.cedula,
    telefono: user.telefono,
    domicilio: user.domicilio,
    salario: user.salario,
    foto: user.foto || null, // base64
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
    // Convertir buffer a base64
    const base64 = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;
    await updateUserPhoto(req.user.id, base64);
    res.json({ ok: true, foto: base64 });
  } catch (e) {
    console.error('Error en uploadProfilePhoto:', e);
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
