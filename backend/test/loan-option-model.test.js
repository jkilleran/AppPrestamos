'use strict';

const assert = require('node:assert/strict');
const { test, describe, afterEach } = require('node:test');

// ============================================================================
// C1.1 — Install deterministic fake for ../db before requiring the model
// ============================================================================

const dbPath = require.resolve('../db');
const modelPath = require.resolve('../models/loan_option.model');

// Save original cache entries so we can restore them (C1.5)
const originalDbCache = require.cache[dbPath];
const originalModelCache = require.cache[modelPath];

let fakePool;
let queryCalls;

function installFakePool() {
  queryCalls = [];
  fakePool = {
    async query(sql, params) {
      queryCalls.push({ sql: String(sql), params });
      return fakePool._nextResult();
    },
    _nextResult: async () => ({ rows: [], rowCount: 0 }),
  };

  require.cache[dbPath] = {
    id: dbPath,
    filename: dbPath,
    loaded: true,
    exports: fakePool,
  };

  // Clear the model from cache so it picks up the new db mock
  delete require.cache[modelPath];
}

function uninstallFakePool() {
  // Restore original db cache entry (or remove our fake)
  if (originalDbCache) {
    require.cache[dbPath] = originalDbCache;
  } else {
    delete require.cache[dbPath];
  }

  // Restore original model cache entry (or remove)
  if (originalModelCache) {
    require.cache[modelPath] = originalModelCache;
  } else {
    delete require.cache[modelPath];
  }
}

describe('loan_option.model.js — actual deleteLoanOption implementation', () => {
  afterEach(() => {
    uninstallFakePool();
  });

  // C1.2 — Successful delete: one query, correct SQL/params, exact return
  test('successful delete returns { id } from RETURNING clause', async () => {
    installFakePool();
    fakePool._nextResult = async () => ({ rows: [{ id: 7 }], rowCount: 1 });

    const { deleteLoanOption } = require('../models/loan_option.model');
    const result = await deleteLoanOption(7);

    assert.equal(queryCalls.length, 1, 'exactly one pool query');
    assert.ok(
      queryCalls[0].sql.includes('DELETE FROM loan_options WHERE id=$1 RETURNING id'),
      `SQL must be DELETE ... RETURNING id, got: ${queryCalls[0].sql}`
    );
    assert.deepEqual(queryCalls[0].params, [7]);
    assert.deepEqual(result, { id: 7 });
  });

  // C1.3 — Zero-row delete: returns undefined
  test('delete of nonexistent row returns undefined', async () => {
    installFakePool();
    fakePool._nextResult = async () => ({ rows: [], rowCount: 0 });

    const { deleteLoanOption } = require('../models/loan_option.model');
    const result = await deleteLoanOption(999);

    assert.equal(queryCalls.length, 1, 'exactly one pool query');
    assert.deepEqual(queryCalls[0].params, [999]);
    assert.equal(result, undefined, 'must return undefined for zero-row delete');
  });

  // C1.4 — Pool rejection: model rejects, no second query
  test('pool query rejection propagates as model rejection', async () => {
    installFakePool();
    fakePool._nextResult = async () => {
      throw new Error('synthetic pool failure');
    };

    const { deleteLoanOption } = require('../models/loan_option.model');

    await assert.rejects(
      () => deleteLoanOption(5),
      { message: 'synthetic pool failure' },
      'model must reject with pool error'
    );

    assert.equal(queryCalls.length, 1, 'only one query attempt');
  });

  // C1.4b — String ID passed through to query params
  test('string ID is passed to pool as-is (controller normalizes before calling)', async () => {
    installFakePool();
    fakePool._nextResult = async () => ({ rows: [{ id: '42' }], rowCount: 1 });

    const { deleteLoanOption } = require('../models/loan_option.model');
    const result = await deleteLoanOption('42');

    assert.equal(queryCalls.length, 1);
    assert.deepEqual(queryCalls[0].params, ['42']);
    assert.deepEqual(result, { id: '42' });
  });
});

// C2 — Cache isolation: prove exact restoration after install/uninstall cycle
test('cache isolation: db and model entries restored to original state', async () => {
  // Capture pre-cycle state (should be original, but be explicit)
  const preCycleDb = require.cache[dbPath];
  const preCycleModel = require.cache[modelPath];

  // Install fake and require model so both cache entries are present
  try {
    installFakePool();
    fakePool._nextResult = async () => ({ rows: [{ id: 1 }], rowCount: 1 });

    // Require the model — this creates the model cache entry using the fake db
    const mod = require('../models/loan_option.model');
    assert.ok(require.cache[dbPath], 'DB cache must exist after install');
    assert.ok(require.cache[modelPath], 'Model cache must exist after require');
    assert.equal(require.cache[dbPath].exports, fakePool, 'DB cache must hold fake pool');
    assert.equal(typeof mod.deleteLoanOption, 'function', 'model must export deleteLoanOption');

    // Now clean up
    uninstallFakePool();

    // C2.4 — Assert exact restoration for db path
    if (originalDbCache) {
      assert.equal(
        require.cache[dbPath], originalDbCache,
        'db cache must be the exact original object after cleanup'
      );
    } else {
      assert.equal(
        require.cache[dbPath], undefined,
        'db cache must be absent after cleanup (no original existed)'
      );
    }

    // C2.4 — Assert exact restoration for model path
    if (originalModelCache) {
      assert.equal(
        require.cache[modelPath], originalModelCache,
        'model cache must be the exact original object after cleanup'
      );
    } else {
      assert.equal(
        require.cache[modelPath], undefined,
        'model cache must be absent after cleanup (no original existed)'
      );
    }
  } finally {
    // C2.5 — Guarantee cleanup even if an assertion throws above
    uninstallFakePool();
  }
});
