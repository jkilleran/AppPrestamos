const express = require('express');
const cors = require('cors');
require('dotenv').config();
const path = require('path');

const authRoutes = require('./routes/auth.routes');
const newsRoutes = require('./routes/news.routes');
const loanRequestRoutes = require('./routes/loan_request.routes');
const loanOptionRoutes = require('./routes/loan_option.routes');
const loanInstallmentRoutes = require('./routes/loan_installment.routes');

const documentStatusRoutes = require('./routes/document_status.routes');
const userDocumentsRoutes = require('./routes/user_documents.routes');
console.log('Cargando settings.routes.js');
const settingsRoutes = require('./routes/settings.routes');
const uploadRoutes = require('./routes/upload.routes');
const pushRoutes = require('./routes/push.routes');
const notificationRoutes = require('./routes/notification.routes');
const suggestionRoutes = require('./routes/suggestion.routes');
const db = require('./db');
const nodemailer = require('nodemailer');
const dns = require('dns').promises;
const net = require('net');
const { startWorker: startEmailOutboxWorker, metrics: emailOutboxMetrics } = require('./services/emailOutbox');
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
app.use('/loan-installments', loanInstallmentRoutes);
app.use('/api/document-status', documentStatusRoutes);
app.use('/api/user-documents', userDocumentsRoutes);
console.log('Registrando rutas /api/settings');
app.use('/api/settings', settingsRoutes);
app.use('/', uploadRoutes); // endpoint /send-document-email
app.use('/api/push', pushRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/suggestions', suggestionRoutes);
console.log('Rutas /api/settings registradas');

// Iniciar worker de outbox persistente si la tabla existe
(async () => {
  try {
    const chk = await db.query("SELECT 1 FROM information_schema.tables WHERE table_name = 'email_outbox'");
    if (chk.rowCount) {
      startEmailOutboxWorker();
    } else {
      console.log('[OUTBOX] Tabla email_outbox no encontrada; worker no iniciado');
    }
  } catch (e) {
    console.warn('[OUTBOX] Error verificando tabla email_outbox:', e.message);
  }
})();

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

// --------- SMTP startup validation (no bloquea, solo warnings) ---------
(function smtpStartupValidation(){
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const port = process.env.SMTP_PORT;
  if (host || user || pass) {
    function warn(msg){ console.warn('[SMTP:VALIDATION]', msg); }
    if (!host) warn('SMTP_HOST faltante');
    if (!user) warn('SMTP_USER faltante');
    if (!pass) warn('SMTP_PASS faltante');
    if (pass && pass.length < 12) warn('SMTP_PASS parece demasiado corta (¿copiaste completa la App Password?)');
    if (port && !/^[0-9]+$/.test(port)) warn('SMTP_PORT no es numérica');
    if (process.env.SMTP_SECURE === 'true' && port === '587') warn('Usas SMTP_SECURE=true con puerto 587. Debe ser false para STARTTLS.');
    if (process.env.SMTP_SECURE !== 'true' && port === '465') warn('Usas puerto 465 pero SMTP_SECURE no es true (posible fallo de handshake).');
  }
})();

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

// Métricas de pool rápidas
app.get('/db-metrics', (req, res) => {
  try {
    if (typeof db.metrics === 'function') {
      return res.json({ ok: true, pool: db.metrics() });
    }
    res.json({ ok: false, error: 'metrics not available' });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// Métricas de outbox
app.get('/email-outbox-metrics', async (req, res) => {
  try {
    const m = await emailOutboxMetrics();
    res.json({ ok: true, outbox: m });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

function parsePortEnv(raw) {
  if (!raw) return 587;
  const first = String(raw).split(',')[0].trim();
  const n = parseInt(first, 10);
  return Number.isFinite(n) ? n : 587;
}

// Verificación SMTP sin enviar adjunto
app.get('/smtp-health', async (req, res) => {
  const started = Date.now();
  try {
    const cfg = {
      host: process.env.SMTP_HOST,
      port: parsePortEnv(process.env.SMTP_PORT),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
      connectionTimeout: 8000,
      socketTimeout: 8000,
      greetingTimeout: 5000,
    };
    if (!cfg.host) return res.status(400).json({ ok: false, error: 'SMTP_HOST faltante' });
    const tr = nodemailer.createTransport(cfg);
    let verifyOk = false; let verifyErr = null;
    try { await tr.verify(); verifyOk = true; } catch (e) { verifyErr = e.message; }
    const ms = Date.now() - started;
    res.json({ ok: true, latency_ms: ms, verify: verifyOk, verify_error: verifyErr });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// Endpoint extendido con diagnóstico profundo y fallback.
app.get('/smtp-health-extended', async (req, res) => {
  const t0 = Date.now();
  function phaseTime(ts){ return Date.now() - ts; }
  const primary = { phases: {}, error: null };
  const fallback = { attempted: false, phases: {}, error: null };
  const suggestions = new Set();
  try {
    const primaryCfg = {
      host: process.env.SMTP_HOST,
      port: parsePortEnv(process.env.SMTP_PORT),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
      connectionTimeout: 8000,
      socketTimeout: 8000,
      greetingTimeout: 5000,
    };
    if (!primaryCfg.host) return res.status(400).json({ ok:false, error:'SMTP_HOST faltante' });
    primary.config = { host: primaryCfg.host, port: primaryCfg.port, secure: primaryCfg.secure, hasUser: !!primaryCfg.auth };
    // Phase 1: DNS
    let ts = Date.now();
    let dnsAddrs = [];
    try {
      const looked = await dns.lookup(primaryCfg.host, { all: true });
      dnsAddrs = looked.map(r => r.address);
      primary.phases.dns_ms = phaseTime(ts);
      primary.dns_addresses = dnsAddrs;
    } catch (e) {
      primary.error = 'DNS_FAIL: '+e.message;
      suggestions.add('Verificar que el hostname existe y no hay bloqueo DNS');
    }
    // Phase 2: Socket connect (si DNS OK)
    if (!primary.error) {
      ts = Date.now();
      primary.socket = { connected: false };
      primary.phases.connect_ms = null;
      await new Promise(resolve => {
        const sock = net.connect(primaryCfg.port, primaryCfg.host, () => {
          primary.socket.connected = true;
          primary.phases.connect_ms = phaseTime(ts);
          sock.end();
          resolve();
        });
        sock.setTimeout(5000, () => { primary.socket.timeout = true; primary.error = 'SOCKET_TIMEOUT_5s'; suggestions.add('Revisar firewall o puerto bloqueado'); sock.destroy(); resolve(); });
        sock.on('error', err => { primary.error = 'SOCKET_ERR: '+err.code; suggestions.add('Verificar salida a internet del hosting'); resolve(); });
      });
    }
    // Phase 3: Verify (STARTTLS / handshake) solo si no hay error previo
    if (!primary.error) {
      ts = Date.now();
      const tr = nodemailer.createTransport(primaryCfg);
      try {
        await tr.verify();
        primary.verify = true;
        primary.phases.verify_ms = phaseTime(ts);
      } catch (e) {
        primary.verify = false;
        primary.verify_error = e.message;
        primary.error = 'VERIFY_FAIL';
        suggestions.add('Confirmar SMTP_USER/SMTP_PASS (App Password)');
        if (e.message && /Invalid login|AUTH/i.test(e.message)) suggestions.add('Regenerar App Password y actualizar entorno');
        if (e.message && /timeout/i.test(e.message)) suggestions.add('Ajustar puertos: probar 587 STARTTLS (SECURE=false)');
      }
    }
    // Fallback logic (similar a upload.controller) si falla y está activado
    function buildFallback(primaryCfg){
      if (process.env.SMTP_ENABLE_FALLBACK !== '1') return null;
      const force = process.env.SMTP_FORCE_FALLBACK === '1';
      if (!force && !(primaryCfg.port === 465 && primaryCfg.secure === true)) return null;
      const fbPort = parseInt(process.env.SMTP_FALLBACK_PORT || '587', 10);
      const fbSecure = process.env.SMTP_FALLBACK_SECURE === 'true';
      const fbHost = process.env.SMTP_FALLBACK_HOST || primaryCfg.host;
      if (fbPort === primaryCfg.port && fbSecure === primaryCfg.secure && fbHost === primaryCfg.host) return null;
      return { ...primaryCfg, host: fbHost, port: fbPort, secure: fbSecure };
    }
    if (primary.error && !primary.verify && !primary.socket?.connected) {
      suggestions.add('Si usas Gmail: usar puerto 587 + SMTP_SECURE=false');
    }
    const fbCfg = primary.error ? buildFallback(primaryCfg) : null;
    if (fbCfg) {
      fallback.attempted = true;
      fallback.config = { host: fbCfg.host, port: fbCfg.port, secure: fbCfg.secure };
      let ts2 = Date.now();
      // Socket test fallback
      await new Promise(resolve => {
        const sock = net.connect(fbCfg.port, fbCfg.host, () => { fallback.phases.connect_ms = phaseTime(ts2); fallback.socket = { connected: true }; sock.end(); resolve(); });
        sock.setTimeout(5000, () => { fallback.socket = { timeout: true }; fallback.error = 'SOCKET_TIMEOUT_5s'; suggestions.add('Fallback también bloqueado'); sock.destroy(); resolve(); });
        sock.on('error', err => { fallback.error = 'SOCKET_ERR:'+err.code; suggestions.add('Verificar red para fallback'); resolve(); });
      });
      if (!fallback.error) {
        ts2 = Date.now();
        const tr2 = nodemailer.createTransport(fbCfg);
        try { await tr2.verify(); fallback.verify = true; fallback.phases.verify_ms = phaseTime(ts2); }
        catch(e){ fallback.verify = false; fallback.verify_error = e.message; fallback.error = 'VERIFY_FAIL'; suggestions.add('Fallback verify falló: revisar credenciales'); }
      }
    }
    const total_ms = Date.now() - t0;
    res.json({ ok: true, total_ms, primary, fallback: fallback.attempted ? fallback : undefined, suggestions: [...suggestions] });
  } catch (e) {
    res.status(500).json({ ok:false, error:e.message });
  }
});

// -------------------------------------------------------------
// Endpoint: /outbound-port-scan
// Permite verificar qué puertos SMTP (u otros) están accesibles desde el host.
// Seguridad: sólo se habilita si OUTBOUND_SCAN_ENABLED=1 para evitar abuso.
// Uso: /outbound-port-scan?host=smtp.gmail.com&ports=587,465,2525,25
// Por defecto host = smtp.gmail.com, puertos = 587,465,2525
// -------------------------------------------------------------
app.get('/outbound-port-scan', async (req, res) => {
  if (process.env.OUTBOUND_SCAN_ENABLED !== '1') {
    return res.status(403).json({ ok: false, error: 'Deshabilitado (definir OUTBOUND_SCAN_ENABLED=1)' });
  }
  const net = require('net');
  const dns = require('dns').promises;
  const host = (req.query.host || 'smtp.gmail.com').toString();
  let ports = (req.query.ports || '587,465,2525').toString()
    .split(',')
    .map(p => parseInt(p.trim(), 10))
    .filter(p => p > 0 && p < 65536);
  if (!ports.length) ports = [587, 465];
  const timeoutMs = parseInt(process.env.OUTBOUND_SCAN_TIMEOUT || '5000', 10);
  const forceIPv4 = process.env.SMTP_FORCE_IPV4 === '1';

  async function resolveHost(h) {
    try {
      const looked = await dns.lookup(h, { all: true, family: forceIPv4 ? 4 : undefined });
      return looked.map(r => r.address);
    } catch (e) {
      return { error: e.message };
    }
  }

  function testPort(h, port) {
    return new Promise(resolve => {
      const started = Date.now();
      let done = false;
      function finish(result) { if (!done) { done = true; resolve(result); } }
      const sock = net.connect({ host: h, port, family: forceIPv4 ? 4 : undefined }, () => {
        const ms = Date.now() - started;
        sock.destroy();
        finish({ port, ok: true, ms });
      });
      sock.setTimeout(timeoutMs, () => {
        sock.destroy();
        finish({ port, ok: false, error: 'TIMEOUT_'+timeoutMs+'ms' });
      });
      sock.on('error', err => {
        finish({ port, ok: false, error: err.code || err.message });
      });
    });
  }

  try {
    const addresses = await resolveHost(host);
    if (addresses.error) {
      return res.json({ ok: false, host, dns_error: addresses.error });
    }
    // Probar solo la primera IP para rapidez; opcionalmente probar todas.
    const ip = Array.isArray(addresses) ? addresses[0] : null;
    const results = {};
    for (const p of ports) {
      // Probamos contra hostname (para permitir balanceo) y capturamos resultado.
      // Si quisiera probar IP directa, podría usar ip en lugar de host.
      // Hostname mejor para STARTTLS banners correctos.
      /* eslint-disable no-await-in-loop */
      results[p] = await testPort(host, p);
      /* eslint-enable no-await-in-loop */
    }

    const summary = {
      open: Object.values(results).filter(r => r.ok).map(r => r.port),
      closed: Object.values(results).filter(r => !r.ok).map(r => r.port),
    };
    const suggestions = [];
    if (!summary.open.length) {
      suggestions.push('Ningún puerto abierto: probable bloqueo outbound en el proveedor (firewall)');
    } else {
      if (summary.open.includes(587) && !summary.open.includes(465)) {
        suggestions.push('Usar puerto 587 con STARTTLS (SMTP_SECURE=false)');
      }
      if (summary.open.includes(2525) && !summary.open.includes(587)) {
        suggestions.push('Configurar un proveedor (SendGrid / Mailers) que acepte puerto 2525');
      }
      if (summary.open.includes(25) && summary.open.length === 1) {
        suggestions.push('Sólo puerto 25 disponible: considerar relay dedicado (no recomendado para Gmail)');
      }
    }
    if (forceIPv4) suggestions.push('Forzando IPv4 activo (SMTP_FORCE_IPV4=1)');
    res.json({ ok: true, host, ip_tested: ip, timeout_ms: timeoutMs, results, summary, suggestions });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('API corriendo en puerto', PORT));
