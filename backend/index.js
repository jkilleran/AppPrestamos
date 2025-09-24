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
const uploadRoutes = require('./routes/upload.routes');
const pushRoutes = require('./routes/push.routes');
const notificationRoutes = require('./routes/notification.routes');
const suggestionRoutes = require('./routes/suggestion.routes');
const db = require('./db');
const app = express();
const corsOptions = {
	origin: '*',
	methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
	allowedHeaders: ['Content-Type', 'Authorization'],
	exposedHeaders: ['Content-Type'],
	credentials: false,
	maxAge: 86400,
};
app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json({ limit: '10mb' }));

// Log simple de solicitudes para diagnóstico
app.use((req, res, next) => {
	if (process.env.LOG_REQUESTS === '1') {
		console.log(`[REQ] ${req.method} ${req.originalUrl}`);
	}
	next();
});

// Servir archivos estáticos de fotos de perfil
app.use('/uploads/profiles', express.static(path.join(__dirname, 'uploads/profiles')));

app.use('/', authRoutes);
app.use('/news', newsRoutes);
app.use('/loan-requests', loanRequestRoutes);
app.use('/loan-options', loanOptionRoutes);
app.use('/api/document-status', documentStatusRoutes);
console.log('Registrando rutas /api/settings');
app.use('/api/settings', settingsRoutes);
app.use('/', uploadRoutes); // endpoint /send-document-email
app.use('/api/push', pushRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/suggestions', suggestionRoutes);
console.log('Rutas /api/settings registradas');

// Ajustes opcionales de base de datos (idempotentes) ejecutados en runtime
async function ensureRuntimeDBTuning() {
	try {
		await db.query(`
			DO $$
			BEGIN
						-- Asegurar columnas necesarias (si la base original no las tenía)
						BEGIN
							ALTER TABLE users ADD COLUMN IF NOT EXISTS document_status_code INTEGER DEFAULT 0;
						EXCEPTION WHEN others THEN
							-- ignorar si falla por permisos, se reportará al usar
							RAISE NOTICE 'No se pudo asegurar columna document_status_code: %', SQLERRM;
						END;
						BEGIN
							ALTER TABLE users ADD COLUMN IF NOT EXISTS document_status_notes JSONB DEFAULT '{}'::jsonb;
						EXCEPTION WHEN others THEN
							RAISE NOTICE 'No se pudo asegurar columna document_status_notes: %', SQLERRM;
						END;

				-- Normalizar cédulas existentes quitando guiones/espacios
				-- (Solo si la tabla es moderadamente pequeña; de lo contrario mover a migración manual)
				UPDATE users
				SET cedula = regexp_replace(cedula, '[^0-9]', '', 'g')
				WHERE cedula ~ '[^0-9]';

				-- Resolver duplicados manteniendo el menor id y anulando la cédula en los demás (para permitir índice único)
				-- Los que queden con cedula NULL requerirán corrección manual posterior.
				WITH dups AS (
					SELECT cedula, array_agg(id ORDER BY id) AS ids, COUNT(*) AS c
					FROM users
					WHERE cedula IS NOT NULL AND cedula <> ''
					GROUP BY cedula
					HAVING COUNT(*) > 1
				), to_clear AS (
					SELECT unnest(ids[2:array_length(ids,1)]) AS id
					FROM dups
				)
				UPDATE users u
				SET cedula = NULL
				FROM to_clear tc
				WHERE u.id = tc.id;

				-- Índice único sobre cédula (si no existe)
				IF NOT EXISTS (
					SELECT 1 FROM pg_class c JOIN pg_index i ON i.indexrelid = c.oid
					JOIN pg_am a ON a.oid = c.relam
					WHERE c.relname = 'users_cedula_uidx'
				) THEN
					BEGIN
						CREATE UNIQUE INDEX users_cedula_uidx ON users(cedula);
					EXCEPTION WHEN others THEN
						-- Ignorar condición de carrera
					END;
				END IF;

				-- Índice GIN sobre notas JSONB (si no existe)
				IF NOT EXISTS (
					SELECT 1 FROM pg_class WHERE relname = 'users_document_status_notes_gin'
				) THEN
					BEGIN
						CREATE INDEX users_document_status_notes_gin ON users USING GIN (document_status_notes);
					EXCEPTION WHEN others THEN
					END;
				END IF;

				-- Constraint de rango para bitmask (0..255)
				IF NOT EXISTS (
					SELECT 1 FROM pg_constraint WHERE conname = 'users_document_status_code_range'
				) THEN
					BEGIN
						ALTER TABLE users ADD CONSTRAINT users_document_status_code_range CHECK (document_status_code BETWEEN 0 AND 255);
					EXCEPTION WHEN others THEN
					END;
				END IF;
			END
			$$;
		`);
		console.log('[DB] Ajustes opcionales verificados/aplicados.');
	} catch (e) {
		console.warn('[DB] No se pudieron aplicar ajustes opcionales:', e.message);
	}
}

ensureRuntimeDBTuning();

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

// Endpoint de diagnóstico de base de datos
app.get('/db-health', async (req, res) => {
	try {
		const started = Date.now();
		const r = await db.query('SELECT NOW() as now, COUNT(*)::int as users_count FROM users');
		const ms = Date.now() - started;
		res.json({ ok: true, now: r.rows[0].now, users: r.rows[0].users_count, latency_ms: ms });
	} catch (e) {
		res.status(500).json({ ok: false, error: e.message });
	}
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('API corriendo en puerto', PORT));
