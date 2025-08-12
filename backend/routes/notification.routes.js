const express = require('express');
const { authMiddleware } = require('../middleware/auth.middleware');
const { getMyNotifications, markOneRead, markAllRead } = require('../controllers/notification.controller');

const router = express.Router();
router.get('/', authMiddleware, getMyNotifications);
router.post('/:id/read', authMiddleware, markOneRead);
router.post('/read-all', authMiddleware, markAllRead);

module.exports = router;
