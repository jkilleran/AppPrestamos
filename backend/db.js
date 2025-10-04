const { Pool } = require('pg');
require('dotenv').config();

if (!process.env.DATABASE_URL) {
  console.warn('[DB] Atención: DATABASE_URL no está definido en el entorno.');
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DB_SSL_DISABLED === '1' ? false : { rejectUnauthorized: false },
  max: process.env.DB_POOL_MAX ? Number(process.env.DB_POOL_MAX) : 10,
  idleTimeoutMillis: process.env.DB_IDLE_TIMEOUT_MS ? Number(process.env.DB_IDLE_TIMEOUT_MS) : 30_000,
  connectionTimeoutMillis: process.env.DB_CONN_TIMEOUT_MS ? Number(process.env.DB_CONN_TIMEOUT_MS) : 8_000,
  keepAlive: true,
});

const SLOW_MS = process.env.DB_SLOW_QUERY_MS ? Number(process.env.DB_SLOW_QUERY_MS) : 400; // log >400ms
const origQuery = pool.query.bind(pool);
pool.query = async function instrumentedQuery(text, params) {
  const start = Date.now();
  try {
    const res = await origQuery(text, params);
    const dur = Date.now() - start;
    if (dur > SLOW_MS) {
      console.warn('[DB][SLOW]', dur + 'ms', truncateSQL(text), shortParams(params));
    } else if (process.env.DB_LOG_ALL === '1') {
      console.log('[DB][Q]', dur + 'ms', truncateSQL(text));
    }
    return res;
  } catch (e) {
    const dur = Date.now() - start;
    console.error('[DB][ERR]', dur + 'ms', truncateSQL(text), e.message);
    throw e;
  }
};

function truncateSQL(sql) {
  if (!sql) return ''; return sql.length > 120 ? sql.slice(0, 117) + '...' : sql.replace(/\s+/g,' ').trim();
}
function shortParams(p) {
  if (!p) return ''; try { return JSON.stringify(p).slice(0,120); } catch { return ''; }
}

pool.metrics = function poolMetrics() {
  return {
    total: pool.totalCount,
    idle: pool.idleCount,
    waiting: pool.waitingCount,
    max: pool.options.max,
  };
};

// Listeners para diagnosticar problemas
pool.on('error', (err) => {
  console.error('[DB] Error inesperado en idle client:', err.message);
});

async function testConnection() {
  const started = Date.now();
  try {
    const res = await pool.query('SELECT NOW() as now');
    const ms = Date.now() - started;
    return { ok: true, now: res.rows[0].now, latency_ms: ms };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

// Auto-probar al cargar (no detiene la app, solo log)
(async () => {
  const r = await testConnection();
  if (r.ok) console.log(`[DB] Conexión OK (latencia ${r.latency_ms}ms)`);
  else console.error('[DB] FALLO conexión inicial:', r.error);
})();

module.exports = pool;
module.exports.testConnection = testConnection;
