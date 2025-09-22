const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/auth.middleware');
const {
  createSuggestionController,
  listMySuggestionsController,
  listAllSuggestionsController,
  updateSuggestionStatusController,
  deleteSuggestionController,
} = require('../controllers/suggestion.controller');

// All routes require auth
router.use(authMiddleware);

// Usuario crea y ve sus sugerencias
router.post('/', createSuggestionController);
router.get('/mine', listMySuggestionsController);

// Admin: listar todas, actualizar estado, eliminar
router.get('/', listAllSuggestionsController);
router.put('/:id/status', updateSuggestionStatusController);
router.delete('/:id', deleteSuggestionController);

module.exports = router;
