const express = require('express');
const { getDocumentTargetEmail, updateDocumentTargetEmail, getDocumentFromEmail, updateDocumentFromEmail } = require('../controllers/settings.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') return res.status(403).json({ error: 'No autorizado' });
  next();
}

const router = express.Router();
router.get('/document-target-email', authMiddleware, requireAdmin, getDocumentTargetEmail);
router.put('/document-target-email', authMiddleware, requireAdmin, updateDocumentTargetEmail);
router.get('/document-from-email', authMiddleware, requireAdmin, getDocumentFromEmail);
router.put('/document-from-email', authMiddleware, requireAdmin, updateDocumentFromEmail);

module.exports = router;
