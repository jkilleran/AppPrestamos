const express = require('express');
const router = express.Router();

const { authMiddleware } = require('../middleware/auth.middleware');
const {
  uploadMiddleware,
  uploadUserDocument,
  getUserDocumentMeta,
  downloadUserDocument,
  listUserDocumentsByCedula,
  getUserDocumentMetaByCedula,
  downloadUserDocumentByCedula,
} = require('../controllers/user_documents.controller');

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'No autorizado' });
  }
  next();
}

// User endpoints
router.post('/:docType', authMiddleware, uploadMiddleware, uploadUserDocument);
router.get('/:docType/meta', authMiddleware, getUserDocumentMeta);
router.get('/:docType', authMiddleware, downloadUserDocument);

// Admin endpoints by cédula
router.get('/by-cedula/list', authMiddleware, requireAdmin, listUserDocumentsByCedula);
router.get('/by-cedula/:docType/meta', authMiddleware, requireAdmin, getUserDocumentMetaByCedula);
router.get('/by-cedula/:docType', authMiddleware, requireAdmin, downloadUserDocumentByCedula);

module.exports = router;
