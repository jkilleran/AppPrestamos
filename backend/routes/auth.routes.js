const express = require('express');
const { register, login, uploadProfilePhoto } = require('../controllers/auth.controller');
const uploadProfilePic = require('../middleware/uploadProfilePic');
const { authMiddleware } = require('../middleware/auth.middleware');
const router = express.Router();

router.post('/register', uploadProfilePic.single('foto'), register);
router.post('/login', login);
router.post('/profile/photo', authMiddleware, uploadProfilePic.single('foto'), uploadProfilePhoto);

module.exports = router;
