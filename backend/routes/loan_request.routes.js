const express = require('express');
const { authMiddleware } = require('../middleware/auth.middleware');
const {
  createLoanRequestController,
  getAllLoanRequestsController,
  updateLoanRequestStatusController,
  getMyLoanRequestsController
} = require('../controllers/loan_request.controller');

const router = express.Router();

router.post('/', authMiddleware, createLoanRequestController);
router.get('/', authMiddleware, getAllLoanRequestsController);
router.get('/mine', authMiddleware, getMyLoanRequestsController);
router.put('/:id/status', authMiddleware, updateLoanRequestStatusController);

module.exports = router;
