const { Pool } = require('pg');
require('dotenv').config();

if (!process.env.DATABASE_URL) {
  console.warn('[DB] Atención: DATABASE_URL no está definido en el entorno.');
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DB_SSL_DISABLED === '1' ? false : { rejectUnauthorized: false },
  max: process.env.DB_POOL_MAX ? Number(process.env.DB_POOL_MAX) : 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 8_000,
});

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
