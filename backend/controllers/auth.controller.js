const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { findUserByEmail, createUser } = require('../models/user.model');

const JWT_SECRET = process.env.JWT_SECRET || 'secret';

async function register(req, res) {
  const { email, password, name, role } = req.body;
  const hash = await bcrypt.hash(password, 10);
  try {
    await createUser({ email, password: hash, name, role });
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: 'Usuario ya existe o datos inválidos' });
  }
}

async function login(req, res) {
  const { email, password } = req.body;
  const user = await findUserByEmail(email);
  if (!user) return res.status(401).json({ error: 'Credenciales inválidas' });
  const valid = await bcrypt.compare(password, user.password);
  if (!valid) return res.status(401).json({ error: 'Credenciales inválidas' });
  const token = jwt.sign({ id: user.id, role: user.role, name: user.name }, JWT_SECRET, { expiresIn: '1d' });
  res.json({ token, role: user.role, name: user.name });
}

module.exports = { register, login };
