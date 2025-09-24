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
// Refactor: evitamos poner cedula = NULL (en algunos entornos la columna es NOT NULL)
// y en su lugar sólo informamos duplicados para corrección manual.
async function ensureRuntimeDBTuning() {
  // Helper para ejecutar queries seguras
  async function safe(label, sql, params = []) {
    try {
      await db.query(sql, params);
      if (process.env.DEBUG_DB_TUNING === '1') console.log(`[DB:TUNING] OK ${label}`);
    } catch (e) {
      console.warn(`[DB:TUNING] Falló ${label}:`, e.message);
    }
  }

  // 1. Asegurar columnas
  await safe('add document_status_code', "ALTER TABLE users ADD COLUMN IF NOT EXISTS document_status_code INTEGER DEFAULT 0");
  await safe('add document_status_notes', "ALTER TABLE users ADD COLUMN IF NOT EXISTS document_status_notes JSONB DEFAULT '{}'::jsonb");

  // 2. Normalizar cédulas (solo si tienen caracteres no numéricos)
  await safe('normalize cedulas', "UPDATE users SET cedula = regexp_replace(cedula, '[^0-9]', '', 'g') WHERE cedula IS NOT NULL AND cedula ~ '[^0-9]'");

  // 3. Detectar duplicados (no modificar si la columna es NOT NULL). Esto evita violar constraints.
  let duplicates = [];
  try {
    const dupRes = await db.query(`
      SELECT cedula, array_agg(id ORDER BY id) AS ids, COUNT(*) AS c
      FROM users
      WHERE cedula IS NOT NULL AND cedula <> ''
      GROUP BY cedula
      HAVING COUNT(*) > 1
    `);
    duplicates = dupRes.rows || [];
  } catch (e) {
    console.warn('[DB:TUNING] No se pudo escanear duplicados de cédula:', e.message);
  }

  if (duplicates.length) {
    console.warn('[DB] Duplicados de cédula detectados. NO se crea índice único. Debe corregirlos manualmente:');
    duplicates.forEach(d => {
      console.warn(`  cedula=${d.cedula} ids=${d.ids.join(',')} count=${d.c}`);
    });
    console.warn('[DB] Sugerencia: corrija o actualice las cédulas duplicadas y reinicie el servicio para intentar crear el índice único.');
  } else {
    // 4. Crear índice único si no hay duplicados
    await safe('unique index cedula', 'CREATE UNIQUE INDEX IF NOT EXISTS users_cedula_uidx ON users(cedula)');
  }

  // 5. Índice GIN sobre notas JSONB
  await safe('gin index document_status_notes', 'CREATE INDEX IF NOT EXISTS users_document_status_notes_gin ON users USING GIN (document_status_notes)');

  // 6. Constraint rango bitmask
  // No existe IF NOT EXISTS para CHECK, así que comprobamos manualmente.
  try {
    const checkRes = await db.query("SELECT 1 FROM pg_constraint WHERE conname = 'users_document_status_code_range'");
    if (!checkRes.rowCount) {
      await safe('add check bitmask range', 'ALTER TABLE users ADD CONSTRAINT users_document_status_code_range CHECK (document_status_code BETWEEN 0 AND 255)');
    }
  } catch (e) {
    console.warn('[DB:TUNING] No se pudo verificar/agregar constraint de rango:', e.message);
  }

  console.log('[DB] Ajustes opcionales finalizados');
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
