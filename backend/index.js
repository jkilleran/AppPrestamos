const express = require('express');
const cors = require('cors');
require('dotenv').config();
const path = require('path');

const authRoutes = require('./routes/auth.routes');
const newsRoutes = require('./routes/news.routes');
const loanRequestRoutes = require('./routes/loan_request.routes');
const loanOptionRoutes = require('./routes/loan_option.routes');

const documentStatusRoutes = require('./routes/document_status.routes');
console.log('Cargando settings.routes.js');
const settingsRoutes = require('./routes/settings.routes');
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
console.log('Registrando rutas /api/settings');
app.use('/api/settings', settingsRoutes);
console.log('Rutas /api/settings registradas');

// Opcional: listar rutas si se activa DEBUG_ROUTES=1
if (process.env.DEBUG_ROUTES === '1') {
	try {
		const routes = [];
		app._router.stack.forEach(mw => {
			if (mw.route && mw.route.path) {
				const methods = Object.keys(mw.route.methods)
					.filter(m => mw.route.methods[m])
					.map(m => m.toUpperCase())
					.join(',');
				routes.push(methods + ' ' + mw.route.path);
			} else if (mw.name === 'router' && mw.handle && mw.handle.stack) {
				mw.handle.stack.forEach(r => {
					if (r.route && r.route.path) {
						const methods = Object.keys(r.route.methods)
							.filter(m => r.route.methods[m])
							.map(m => m.toUpperCase())
							.join(',');
						routes.push(methods + ' ' + (mw.regexp?.source || '') + r.route.path);
					}
				});
			}
		});
		console.log('DEBUG_ROUTES listado de rutas:', routes);
	} catch (e) {
		console.log('Error listando rutas', e);
	}
}

app.get('/', (req, res) => res.send('API de Préstamos funcionando'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('API corriendo en puerto', PORT));
