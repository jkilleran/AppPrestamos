// Middleware de autenticación de ejemplo
module.exports = (req, res, next) => {
  // Aquí deberías validar el token y establecer req.user
  // Por ahora, simula un usuario autenticado con id 1
  req.user = { id: 1 };
  next();
};
