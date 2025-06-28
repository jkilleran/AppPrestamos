const express = require('express');
const { authMiddleware } = require('../middleware/auth.middleware');
const {
  getAllLoanOptionsController,
  createLoanOptionController,
  updateLoanOptionController,
  deleteLoanOptionController
} = require('../controllers/loan_option.controller');

const router = express.Router();

router.get('/', authMiddleware, getAllLoanOptionsController);
router.post('/', authMiddleware, createLoanOptionController);
router.put('/:id', authMiddleware, updateLoanOptionController);
router.delete('/:id', authMiddleware, deleteLoanOptionController);

module.exports = router;
