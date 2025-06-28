const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { findUserByEmail, createUser } = require('../models/user.model');

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

async function register(req, res) {
  const { email, password, name, role, cedula, telefono } = req.body;
  // Validación de campos obligatorios
  if (!email || !password || !name || !cedula || !telefono) {
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
    await createUser({ email, password: hash, name, role, cedula, telefono });
    res.json({ ok: true });
  } catch (e) {
    console.error(e); // Log del error real
    res.status(400).json({ error: 'Usuario ya existe o datos inválidos' });
  }
}

async function login(req, res) {
  const { email, password } = req.body;
  const user = await findUserByEmail(email);
  console.log('Login intento:', { email, passwordEnviado: password, userEnBase: user }); // <-- Agregado para depuración
  if (!user) return res.status(401).json({ error: 'Credenciales inválidas' });
  const valid = await bcrypt.compare(password, user.password);
  console.log('Resultado bcrypt.compare:', valid); // <-- Agregado para depuración
  if (!valid) return res.status(401).json({ error: 'Credenciales inválidas' });
  const token = jwt.sign({ id: user.id, role: user.role, name: user.name }, JWT_SECRET, { expiresIn: '1d' });
  res.json({ token, role: user.role, name: user.name });
}

module.exports = { register, login };
