const express = require('express');
const router = express.Router();
const { getUserDocumentStatus, updateUserDocumentStatus, getDocumentStatusByEmail, updateDocumentStatusByEmail } = require('../controllers/document_status.controller');
const { authMiddleware } = require('../middleware/auth.middleware');
// Middleware simple de verificación de rol admin
function requireAdmin(req, res, next) {
	if (!req.user || req.user.role !== 'admin') {
		return res.status(403).json({ error: 'No autorizado' });
	}
	next();
}

// GET: Obtener el status de documentos del usuario autenticado
router.get('/', authMiddleware, getUserDocumentStatus);

// PUT: Actualizar el status de documentos del usuario autenticado
router.put('/', authMiddleware, updateUserDocumentStatus);

// Rutas admin por email
router.get('/by-email', authMiddleware, requireAdmin, getDocumentStatusByEmail);
router.put('/by-email', authMiddleware, requireAdmin, updateDocumentStatusByEmail);

module.exports = router;
