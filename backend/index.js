const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth.routes');
const newsRoutes = require('./routes/news.routes');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/', authRoutes);
app.use('/news', newsRoutes);

app.get('/', (req, res) => res.send('API de Préstamos funcionando'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('API corriendo en puerto', PORT));
