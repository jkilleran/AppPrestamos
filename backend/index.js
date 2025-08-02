const express = require('express');
const cors = require('cors');
require('dotenv').config();
const path = require('path');

const authRoutes = require('./routes/auth.routes');
const newsRoutes = require('./routes/news.routes');
const loanRequestRoutes = require('./routes/loan_request.routes');
const loanOptionRoutes = require('./routes/loan_option.routes');

const documentStatusRoutes = require('./routes/document_status.routes');
const app = express();
app.use(cors());
app.use(express.json());

// Servir archivos estáticos de fotos de perfil
app.use('/uploads/profiles', express.static(path.join(__dirname, 'uploads/profiles')));

app.use('/', authRoutes);
app.use('/news', newsRoutes);
app.use('/loan-requests', loanRequestRoutes);
app.use('/loan-options', loanOptionRoutes);
app.use('/api/document-status', documentStatusRoutes);

app.get('/', (req, res) => res.send('API de Préstamos funcionando'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('API corriendo en puerto', PORT));
