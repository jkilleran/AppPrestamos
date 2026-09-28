'use strict';

// ============================================================================
// TASK-004-D — Isolated HTTP-level regression suite for mounted loan-options
// routes. Real router + real authMiddleware + real controllers; models/db are
// mocked BEFORE the router is imported so no DB connection/query can occur.
// No real credentials/tokens: JWTs are signed locally with a test-only secret.
// TASK-004-D2: the AUTHENTIC process-entry JWT env state and all seven app-module
// require.cache states are captured before any application import or mutation,
// then restored + asserted in-process. The generic present/absent restoration
// branches are proven separately with isolated synthetic cache fixtures.
// ============================================================================

const assert = require('node:assert/strict');
const { test, beforeEach, after } = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');
const request = require('supertest');

// ---------------------------------------------------------------------------
// TASK-004-D2 — D2.1/D2.2: AUTHENTIC process-entry capture. JWT_SECRET
// presence/value and the seven application cache states are recorded right
// after the third-party requires above and BEFORE any application require(),
// environment mutation, mock installation or cache deletion. No application
// module is imported before this point (require.resolve executes nothing).
// Values/exports are never printed.
// ---------------------------------------------------------------------------

const TEST_JWT_SECRET = 'loan-option-routes-test-secret-only'; // test-only literal

// D2.1 — authentic JWT_SECRET presence/value at process entry.
const authenticJwtPresent = Object.prototype.hasOwnProperty.call(process.env, 'JWT_SECRET');
const authenticJwtValue = process.env.JWT_SECRET; // never logged or printed

// D2.1 — all seven application boundaries captured with presence + exact
// cache-entry/export identity. Every record and the snapshot map are frozen,
// so the authentic baseline can never be mutated or replaced after capture.
const SEVEN_PATHS = [
  '../db',
  '../models/loan_option.model',
  '../models/user.model',
  '../utils/authConfig',
  '../middleware/auth.middleware',
  '../controllers/loan_option.controller',
  '../routes/loan_option.routes',
];

const authenticSnapshot = {};
for (const requestPath of SEVEN_PATHS) {
  const filename = require.resolve(requestPath);
  const entry = require.cache[filename];
  authenticSnapshot[requestPath] = Object.freeze({
    filename,
    existed: entry !== undefined,
    entry,
    exports: entry ? entry.exports : undefined,
  });
}
Object.freeze(authenticSnapshot);

// Resolved filename shortcuts for the composition paths used individually below.
const authConfigPath = authenticSnapshot['../utils/authConfig'].filename;
const authMiddlewarePath = authenticSnapshot['../middleware/auth.middleware'].filename;
const controllerPath = authenticSnapshot['../controllers/loan_option.controller'].filename;
const routerPath = authenticSnapshot['../routes/loan_option.routes'].filename;

// D2.3 — test-only secret (never a real credential/token) installed AFTER capture.
process.env.JWT_SECRET = TEST_JWT_SECRET;

function installMock(requestPath, exports) {
  const filename = require.resolve(requestPath);
  require.cache[filename] = {
    id: filename,
    filename,
    loaded: true,
    exports,
  };
}

// ---------------------------------------------------------------------------
// D3 — boundary mocks installed BEFORE requiring controller/router
// ---------------------------------------------------------------------------

const state = {
  createCalls: [],
  updateCalls: [],
  deleteCalls: [],
  getAllCalls: [],
  userFindCalls: [],
  dbQueries: [],
  throwOnCreate: false,
  throwOnUpdate: false,
  throwOnDelete: false,
  updateReturnsUndefined: false,
  deleteReturnsUndefined: false,
};

// Mocked DB: any query would be recorded (tests assert zero) — proves no live DB.
installMock('../db', {
  async query(sql, params) {
    state.dbQueries.push({ sql: String(sql), params });
    return { rows: [], rowCount: 0 };
  },
});

// Mocked loan-option model: call-recording + controllable behavior flags.
installMock('../models/loan_option.model', {
  createLoanOption: async (...args) => {
    state.createCalls.push({ args });
    if (state.throwOnCreate) {
      throw new Error('SQL ERROR: SELECT * FROM secret_table WHERE password = "leak"');
    }
    return { id: 1, min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro', ingreso_minimo: null, ...args[0] };
  },
  updateLoanOption: async (...args) => {
    state.updateCalls.push({ args });
    if (state.throwOnUpdate) {
      throw new Error('DB failure: SQLSTATE[23503] detail=secret');
    }
    if (state.updateReturnsUndefined) return undefined;
    return { id: Number(args[0]) || 42, ...args[1] };
  },
  deleteLoanOption: async (...args) => {
    state.deleteCalls.push({ args });
    if (state.throwOnDelete) {
      throw new Error('connection reset: password=hunter2 in DSN');
    }
    if (state.deleteReturnsUndefined) return undefined;
    return { id: Number(args[0]) };
  },
  getAllLoanOptions: async (...args) => {
    state.getAllCalls.push({ args });
    return [{ id: 1, min_amount: '1000', max_amount: '5000', interest: '12', months: 12, categoria_minima: 'Hierro', ingreso_minimo: null }];
  },
});

// Mocked user model (controller imports findUserById for non-admin GET).
installMock('../models/user.model', {
  findUserById: async (id) => {
    state.userFindCalls.push(id);
    return { id, name: 'Route Test User', salario: 5000, categoria: 'Hierro' };
  },
});

// ---------------------------------------------------------------------------
// D2.3 — fresh isolated Express app mounting the ACTUAL router at /loan-options.
// The four composition cache entries are deleted (present or absent in the
// authentic snapshot) and the actual router is imported AFTER the test secret
// and the three boundary mocks are installed, so the fresh graph binds only to
// the mocked DB/model boundaries while still using the real router, auth
// middleware and controller.
// ---------------------------------------------------------------------------

delete require.cache[authConfigPath];
delete require.cache[authMiddlewarePath];
delete require.cache[controllerPath];
delete require.cache[routerPath];

const loanOptionRoutes = require('../routes/loan_option.routes');

const app = express();
app.use(express.json());
app.use('/loan-options', loanOptionRoutes);

// D2.3 — direct same-process assertions that the composition graph is fresh
// and bound to the test-only secret (boolean comparisons: no value printed).
const freshAuthConfigEntry = require.cache[authConfigPath];
const freshAuthMiddlewareEntry = require.cache[authMiddlewarePath];
const freshControllerEntry = require.cache[controllerPath];
const freshRouterEntry = require.cache[routerPath];
assert.equal(
  freshAuthConfigEntry !== undefined &&
    freshAuthConfigEntry !== authenticSnapshot['../utils/authConfig'].entry,
  true,
  'D2.3 authConfig must be a fresh entry distinct from the authentic snapshot entry',
);
assert.equal(
  freshAuthMiddlewareEntry !== undefined &&
    freshAuthMiddlewareEntry !== authenticSnapshot['../middleware/auth.middleware'].entry,
  true,
  'D2.3 auth.middleware must be a fresh entry distinct from the authentic snapshot entry',
);
assert.equal(freshControllerEntry !== undefined, true, 'D2.3 controller must be freshly imported');
assert.equal(freshRouterEntry !== undefined, true, 'D2.3 router must be freshly imported');
assert.equal(
  freshAuthConfigEntry.exports.JWT_SECRET === TEST_JWT_SECRET,
  true,
  'D2.3 fresh authConfig must bind to the test-only secret',
);

// D2 — locally signed test JWT using the configured (test) secret
function authToken({ id, role }) {
  return jwt.sign(
    { id, role, name: 'Route Test', email: 'routes@example.test' },
    process.env.JWT_SECRET,
    { expiresIn: '1h' },
  );
}

const adminAuth = () => `Bearer ${authToken({ id: 1, role: 'admin' })}`;
const clientAuth = () => `Bearer ${authToken({ id: 11, role: 'cliente' })}`;

const validBody = { min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro' };

beforeEach(() => {
  state.createCalls.length = 0;
  state.updateCalls.length = 0;
  state.deleteCalls.length = 0;
  state.getAllCalls.length = 0;
  state.userFindCalls.length = 0;
  state.dbQueries.length = 0;
  state.throwOnCreate = false;
  state.throwOnUpdate = false;
  state.throwOnDelete = false;
  state.updateReturnsUndefined = false;
  state.deleteReturnsUndefined = false;
});

// ---------------------------------------------------------------------------
// TASK-004-D2 — D2.4: ONE deterministic restoration helper accepting an
// explicit snapshot and an explicit cache-like target. Production teardown
// invokes it ONLY with the authentic process-entry snapshot and require.cache;
// the D2.5 branch tests invoke it with locally constructed synthetic fixtures.
// ---------------------------------------------------------------------------

function restoreCacheEntries(snapshot, cacheTarget) {
  for (const requestPath of Object.keys(snapshot)) {
    const record = snapshot[requestPath];
    if (record.existed) cacheTarget[record.filename] = record.entry;
    else delete cacheTarget[record.filename];
  }
}

function restoreState() {
  // D2.6 — authentic JWT_SECRET restored to its process-entry presence/value.
  if (authenticJwtPresent) process.env.JWT_SECRET = authenticJwtValue;
  else delete process.env.JWT_SECRET;

  // D2.4 — authentic snapshot only: exact entry if it existed, else absent.
  restoreCacheEntries(authenticSnapshot, require.cache);
}

function assertRestored(label) {
  // D2.6 — JWT presence/value compared as booleans so no value can be revealed.
  assert.equal(
    Object.prototype.hasOwnProperty.call(process.env, 'JWT_SECRET'),
    authenticJwtPresent,
    `${label}: JWT_SECRET presence must equal the authentic process-entry state`,
  );
  if (authenticJwtPresent) {
    assert.equal(
      process.env.JWT_SECRET === authenticJwtValue,
      true,
      `${label}: JWT_SECRET value must equal the authentic process-entry value`,
    );
  }

  // D2.6 — present entries keep exact cache-entry/export identity; absent stay absent.
  for (const requestPath of SEVEN_PATHS) {
    const record = authenticSnapshot[requestPath];
    const current = require.cache[record.filename];
    if (record.existed) {
      assert.equal(
        current === record.entry,
        true,
        `${label}: ${requestPath} must restore the exact authentic cache entry`,
      );
      assert.equal(
        current.exports === record.exports,
        true,
        `${label}: ${requestPath} must restore the exact authentic exports object`,
      );
    } else {
      assert.equal(
        current === undefined,
        true,
        `${label}: ${requestPath} must be absent after cleanup`,
      );
    }
  }
}

function takeSnapshot() {
  return {
    jwtPresent: Object.prototype.hasOwnProperty.call(process.env, 'JWT_SECRET'),
    jwtValue: process.env.JWT_SECRET,
    entries: SEVEN_PATHS.map((requestPath) => require.cache[authenticSnapshot[requestPath].filename]),
  };
}

// D2.6 — same-process teardown assertions; a failure here fails the suite.
after(() => {
  restoreState();
  assertRestored('after() hook');
});

// ============================================================================
// D4 — authentication and authorization boundary
// ============================================================================

test('D4 GET /loan-options without token returns 401 Token requerido with zero model calls', async () => {
  const res = await request(app).get('/loan-options').expect(401);
  assert.deepEqual(res.body, { error: 'Token requerido' });
  assert.equal(state.getAllCalls.length, 0);
  assert.equal(state.userFindCalls.length, 0);
  assert.equal(state.dbQueries.length, 0);
});

test('D4 GET /loan-options with invalid token returns 401 Token inválido with zero model calls', async () => {
  const badToken = jwt.sign({ id: 1, role: 'admin' }, 'wrong-secret', { expiresIn: '1h' });
  const res = await request(app)
    .get('/loan-options')
    .set('Authorization', `Bearer ${badToken}`)
    .expect(401);
  assert.deepEqual(res.body, { error: 'Token inválido' });
  assert.equal(state.getAllCalls.length, 0);
  assert.equal(state.dbQueries.length, 0);
});

test('D4 authenticated client GET /loan-options is allowed with one getAll call and zero db queries', async () => {
  const res = await request(app)
    .get('/loan-options')
    .set('Authorization', clientAuth())
    .expect(200);
  assert.ok(Array.isArray(res.body), 'GET must return an array');
  assert.equal(state.getAllCalls.length, 1, 'exactly one getAll call');
  assert.equal(state.userFindCalls.length, 1, 'client GET looks up user salary filter');
  assert.equal(state.dbQueries.length, 0, 'zero db queries — no live DB access');
});

test('D4 client POST /loan-options returns 403 No autorizado with zero create calls', async () => {
  const res = await request(app)
    .post('/loan-options')
    .set('Authorization', clientAuth())
    .send(validBody)
    .expect(403);
  assert.deepEqual(res.body, { error: 'No autorizado' });
  assert.equal(state.createCalls.length, 0, 'zero create calls');
  assert.equal(state.dbQueries.length, 0);
});

test('D4 client PUT /loan-options/7 returns 403 No autorizado with zero update calls', async () => {
  const res = await request(app)
    .put('/loan-options/7')
    .set('Authorization', clientAuth())
    .send(validBody)
    .expect(403);
  assert.deepEqual(res.body, { error: 'No autorizado' });
  assert.equal(state.updateCalls.length, 0, 'zero update calls');
  assert.equal(state.dbQueries.length, 0);
});

test('D4 client DELETE /loan-options/7 returns 403 No autorizado with zero delete calls', async () => {
  const res = await request(app)
    .delete('/loan-options/7')
    .set('Authorization', clientAuth())
    .expect(403);
  assert.deepEqual(res.body, { error: 'No autorizado' });
  assert.equal(state.deleteCalls.length, 0, 'zero delete calls');
  assert.equal(state.dbQueries.length, 0);
});

// ============================================================================
// D5 — admin mutations reach persistence exactly once with 201/200/200
// ============================================================================

test('D5 admin valid POST returns 201 with exactly one create call and normalized payload', async () => {
  const res = await request(app)
    .post('/loan-options')
    .set('Authorization', adminAuth())
    .send({ min_amount: '1000', max_amount: '5000', interest: '12', months: '6', categoria_minima: 'plata' })
    .expect(201);
  assert.equal(state.createCalls.length, 1, 'exactly one create call');
  const payload = state.createCalls[0].args[0];
  assert.equal(payload.min_amount, 1000);
  assert.equal(payload.max_amount, 5000);
  assert.equal(payload.interest, 12);
  assert.equal(payload.months, 6);
  assert.equal(payload.categoria_minima, 'Plata');
  assert.equal(typeof res.body.id, 'number', '201 must return the created object');
  assert.equal(state.dbQueries.length, 0, 'zero db queries — no live DB access');
});

test('D5 admin valid PUT /loan-options/7 returns 200 with exactly one update call and numeric id 7', async () => {
  const res = await request(app)
    .put('/loan-options/7')
    .set('Authorization', adminAuth())
    .send(validBody)
    .expect(200);
  assert.equal(state.updateCalls.length, 1, 'exactly one update call');
  const [routeId, payload] = state.updateCalls[0].args;
  assert.equal(routeId, 7, 'route id normalized to numeric 7');
  assert.equal(payload.min_amount, 1000);
  assert.equal(payload.categoria_minima, 'Hierro');
  assert.equal(res.body.id, 7, '200 must return the updated object');
  assert.equal(state.dbQueries.length, 0, 'zero db queries — no live DB access');
});

test('D5 admin valid DELETE /loan-options/7 returns 200 success with exactly one delete call and numeric id 7', async () => {
  const res = await request(app)
    .delete('/loan-options/7')
    .set('Authorization', adminAuth())
    .expect(200);
  assert.deepEqual(res.body, { success: true });
  assert.equal(state.deleteCalls.length, 1, 'exactly one delete call');
  assert.equal(state.deleteCalls[0].args[0], 7, 'route id normalized to numeric 7');
  assert.equal(state.dbQueries.length, 0, 'zero db queries — no live DB access');
});

// ============================================================================
// D6 — invalid admin payload and malformed IDs return 400 with zero mutations
// ============================================================================

test('D6 admin POST with invalid payload returns 400 Datos inválidos with zero create calls', async () => {
  const res = await request(app)
    .post('/loan-options')
    .set('Authorization', adminAuth())
    .send({ ...validBody, min_amount: true })
    .expect(400);
  assert.deepEqual(res.body, { error: 'Datos inválidos' });
  assert.equal(state.createCalls.length, 0, 'zero create calls');
  assert.equal(state.dbQueries.length, 0);
});

test('D6 admin PUT /loan-options/1e2 with malformed id returns 400 Datos inválidos with zero update calls', async () => {
  const res = await request(app)
    .put('/loan-options/1e2')
    .set('Authorization', adminAuth())
    .send(validBody)
    .expect(400);
  assert.deepEqual(res.body, { error: 'Datos inválidos' });
  assert.equal(state.updateCalls.length, 0, 'zero update calls');
  assert.equal(state.dbQueries.length, 0);
});

test('D6 admin DELETE /loan-options/0 returns 400 Datos inválidos with zero delete calls', async () => {
  const res = await request(app)
    .delete('/loan-options/0')
    .set('Authorization', adminAuth())
    .expect(400);
  assert.deepEqual(res.body, { error: 'Datos inválidos' });
  assert.equal(state.deleteCalls.length, 0, 'zero delete calls');
  assert.equal(state.dbQueries.length, 0);
});

test('D6 admin PUT with invalid body returns 400 Datos inválidos with zero update calls', async () => {
  const res = await request(app)
    .put('/loan-options/7')
    .set('Authorization', adminAuth())
    .send({ min_amount: 'invalid', max_amount: 5000, interest: 12, months: 6 })
    .expect(400);
  assert.deepEqual(res.body, { error: 'Datos inválidos' });
  assert.equal(state.updateCalls.length, 0, 'zero update calls');
});

// ============================================================================
// D7 — missing records 404; persistence exceptions generic 500, no leaks
// ============================================================================

test('D7 admin PUT on missing record returns 404 Opción no encontrada', async () => {
  state.updateReturnsUndefined = true;
  const res = await request(app)
    .put('/loan-options/999')
    .set('Authorization', adminAuth())
    .send(validBody)
    .expect(404);
  assert.deepEqual(res.body, { error: 'Opción no encontrada' });
  assert.equal(state.updateCalls.length, 1, 'exactly one update attempt');
  assert.equal(state.updateCalls[0].args[0], 999);
});

test('D7 admin DELETE on missing record returns 404 Opción no encontrada', async () => {
  state.deleteReturnsUndefined = true;
  const res = await request(app)
    .delete('/loan-options/999')
    .set('Authorization', adminAuth())
    .expect(404);
  assert.deepEqual(res.body, { error: 'Opción no encontrada' });
  assert.equal(state.deleteCalls.length, 1, 'exactly one delete attempt');
  assert.equal(state.deleteCalls[0].args[0], 999);
});

test('D7 create persistence exception returns 500 Error interno without leaking SQL/secret details', async () => {
  state.throwOnCreate = true;
  const res = await request(app)
    .post('/loan-options')
    .set('Authorization', adminAuth())
    .send(validBody)
    .expect(500);
  assert.deepEqual(res.body, { error: 'Error interno' });
  const raw = JSON.stringify(res.body);
  assert.equal(raw.includes('SQL'), false, 'must not leak SQL');
  assert.equal(raw.includes('secret'), false, 'must not leak secret text');
  assert.equal(state.createCalls.length, 1, 'one persistence attempt recorded');
});

test('D7 update persistence exception returns 500 Error interno without leaking details', async () => {
  state.throwOnUpdate = true;
  const res = await request(app)
    .put('/loan-options/7')
    .set('Authorization', adminAuth())
    .send(validBody)
    .expect(500);
  assert.deepEqual(res.body, { error: 'Error interno' });
  assert.equal(JSON.stringify(res.body).includes('SQLSTATE'), false, 'must not leak SQLSTATE');
  assert.equal(state.updateCalls.length, 1, 'one persistence attempt recorded');
});

test('D7 delete persistence exception returns 500 Error interno without leaking details', async () => {
  state.throwOnDelete = true;
  const res = await request(app)
    .delete('/loan-options/7')
    .set('Authorization', adminAuth())
    .expect(500);
  assert.deepEqual(res.body, { error: 'Error interno' });
  assert.equal(JSON.stringify(res.body).includes('password'), false, 'must not leak password/DSN text');
  assert.equal(state.deleteCalls.length, 1, 'one persistence attempt recorded');
});

// ============================================================================
// TASK-004-D2 — D2.5: generic helper branch coverage with SYNTHETIC fixtures.
// Locally constructed cache-like objects and snapshot records only: no
// application import, no require.cache access, no DB, and the synthetic keys
// can never be part of the authentic seven-path snapshot.
// ============================================================================

test('D2.5 synthetic present snapshot restores the exact sentinel cache entry and exports identity', () => {
  const syntheticKey = 'synthetic-d2-present.js'; // not a real file; not one of the seven authentic paths
  const sentinelExports = { marker: 'd2-present-exports' };
  const sentinelEntry = {
    id: 'synthetic-present',
    filename: syntheticKey,
    loaded: true,
    exports: sentinelExports,
  };
  const replacedEntry = {
    id: 'synthetic-replaced',
    filename: syntheticKey,
    loaded: true,
    exports: { marker: 'replaced-exports' },
  };
  const syntheticCache = { [syntheticKey]: replacedEntry };
  const syntheticSnapshot = {
    [syntheticKey]: Object.freeze({
      filename: syntheticKey,
      existed: true,
      entry: sentinelEntry,
      exports: sentinelExports,
    }),
  };

  assert.equal(
    SEVEN_PATHS.every((requestPath) => authenticSnapshot[requestPath].filename !== syntheticKey),
    true,
    'synthetic key must never be one of the authentic seven paths',
  );

  restoreCacheEntries(syntheticSnapshot, syntheticCache);

  assert.equal(
    syntheticCache[syntheticKey] === sentinelEntry,
    true,
    'present branch must restore the exact sentinel cache entry',
  );
  assert.equal(
    syntheticCache[syntheticKey].exports === sentinelExports,
    true,
    'present branch must restore the exact sentinel exports object',
  );
});

test('D2.5 synthetic absent snapshot removes the inserted sentinel entry', () => {
  const syntheticKey = 'synthetic-d2-absent.js'; // not a real file; not one of the seven authentic paths
  const sentinelEntry = {
    id: 'synthetic-absent',
    filename: syntheticKey,
    loaded: true,
    exports: { marker: 'd2-absent-exports' },
  };
  const syntheticCache = { [syntheticKey]: sentinelEntry };
  const syntheticSnapshot = {
    [syntheticKey]: Object.freeze({
      filename: syntheticKey,
      existed: false,
      entry: undefined,
      exports: undefined,
    }),
  };

  assert.equal(
    SEVEN_PATHS.every((requestPath) => authenticSnapshot[requestPath].filename !== syntheticKey),
    true,
    'synthetic key must never be one of the authentic seven paths',
  );

  restoreCacheEntries(syntheticSnapshot, syntheticCache);

  assert.equal(
    syntheticCache[syntheticKey] === undefined,
    true,
    'absent branch must delete the inserted sentinel entry',
  );
});

// ============================================================================
// TASK-004-D2 — D2.6/D2.7 final same-process AUTHENTIC teardown proof (last)
// ============================================================================

test('D2.6 D2.7 authentic teardown restores JWT env and all seven cache paths and a second cleanup is idempotent', () => {
  assert.equal(Object.isFrozen(authenticSnapshot), true, 'authentic snapshot map must stay frozen');
  assert.equal(Object.keys(authenticSnapshot).length, 7, 'authentic snapshot must cover exactly the seven paths');
  assert.equal(
    SEVEN_PATHS.every((requestPath) => Object.isFrozen(authenticSnapshot[requestPath])),
    true,
    'every authentic snapshot record must stay frozen',
  );

  // First cleanup: restore the exact authentic process-entry state.
  restoreState();
  assertRestored('post-cleanup #1');

  const afterFirst = takeSnapshot();

  // D2.7 — a second cleanup call must not corrupt or change the restored state.
  restoreState();
  assertRestored('post-cleanup #2');

  const afterSecond = takeSnapshot();
  assert.equal(
    afterSecond.jwtPresent === afterFirst.jwtPresent,
    true,
    'second cleanup must preserve JWT_SECRET presence',
  );
  assert.equal(
    afterSecond.jwtValue === afterFirst.jwtValue,
    true,
    'second cleanup must preserve JWT_SECRET value',
  );
  for (let i = 0; i < SEVEN_PATHS.length; i += 1) {
    assert.equal(
      afterSecond.entries[i] === afterFirst.entries[i],
      true,
      `second cleanup must preserve cache identity for ${SEVEN_PATHS[i]}`,
    );
  }
});
