const express = require('express');
const { getNewsController, setNewsController } = require('../controllers/news.controller');
const { authMiddleware } = require('../middleware/auth.middleware');
const router = express.Router();

router.get('/', getNewsController);
router.put('/', authMiddleware, setNewsController);

module.exports = router;
