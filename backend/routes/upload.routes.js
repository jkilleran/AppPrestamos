const express = require('express');
const router = express.Router();
const { uploadSingle, sendDocumentEmail, testEmail } = require('../controllers/upload.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

// Auth optional? If we want user data, keep auth.
router.post('/send-document-email', authMiddleware, uploadSingle, sendDocumentEmail);
router.get('/test-email', authMiddleware, testEmail);

module.exports = router;
