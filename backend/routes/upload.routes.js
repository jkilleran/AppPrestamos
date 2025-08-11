const express = require('express');
const router = express.Router();
const { uploadSingle, sendDocumentEmail, testEmail, emailConfig } = require('../controllers/upload.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

function requireAdmin(req, res, next) {
	if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
	next();
}

// Auth optional? If we want user data, keep auth.
router.post('/send-document-email', authMiddleware, uploadSingle, sendDocumentEmail);
router.get('/test-email', authMiddleware, testEmail);
router.get('/email-config', authMiddleware, requireAdmin, emailConfig);

module.exports = router;
