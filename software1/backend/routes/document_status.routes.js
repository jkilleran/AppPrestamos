const express = require('express');
const router = express.Router();
const { getUserDocumentStatus, updateUserDocumentStatus } = require('../controllers/document_status.controller');
const authenticate = require('../middleware/authenticate');

// GET: Obtener el status de documentos del usuario autenticado
router.get('/', authenticate, getUserDocumentStatus);

// PUT: Actualizar el status de documentos del usuario autenticado
router.put('/', authenticate, updateUserDocumentStatus);

module.exports = router;
