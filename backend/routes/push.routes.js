const express = require('express');
const { authMiddleware } = require('../middleware/auth.middleware');
const { registerToken, unregisterToken, testPush } = require('../controllers/push.controller');

const router = express.Router();
router.post('/register', authMiddleware, registerToken);
router.delete('/register', authMiddleware, unregisterToken);
router.post('/test', authMiddleware, testPush);

module.exports = router;
