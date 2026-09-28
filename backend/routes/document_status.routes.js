const express = require('express');
const router = express.Router();
const {
	getUserDocumentStatus,
	updateUserDocumentStatus,
	getDocumentStatusByEmail,
	updateDocumentStatusByEmail,
	getDocumentStatusByCedula,
	updateDocumentStatusByCedula,
	listPendingApprovals,
} = require('../controllers/document_status.controller');
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

// Legacy self-status endpoint. Uploads update "enviado" server-side; only an
// admin may use this direct bitmask endpoint, preventing user auto-approval.
router.put('/', authMiddleware, requireAdmin, updateUserDocumentStatus);

// Rutas admin por email
router.get('/by-email', authMiddleware, requireAdmin, getDocumentStatusByEmail);
router.put('/by-email', authMiddleware, requireAdmin, updateDocumentStatusByEmail);
// Rutas admin por cédula
router.get('/by-cedula', authMiddleware, requireAdmin, getDocumentStatusByCedula);
router.put('/by-cedula', authMiddleware, requireAdmin, updateDocumentStatusByCedula);

// Rutas admin: pendientes por aprobar
router.get('/pending', authMiddleware, requireAdmin, listPendingApprovals);

module.exports = router;
