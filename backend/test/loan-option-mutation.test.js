'use strict';

const assert = require('node:assert/strict');
const { test, describe, beforeEach } = require('node:test');

function installMock(request, exports) {
  const filename = require.resolve(request);
  require.cache[filename] = {
    id: filename,
    filename,
    loaded: true,
    exports,
  };
}

// ============================================================================
// Call-recording state + controllable behavior via flags
// ============================================================================

const calls = {
  create: [],
  update: [],
  delete: [],
  getAll: [],
};

// State flags that tests mutate — mock functions read from these
const mockState = {
  throwOnCreate: false,
  throwOnUpdate: false,
  throwOnDelete: false,
  returnUndefinedOnUpdate: false,
  returnUndefinedOnDelete: false,
};

const mockModel = {
  createLoanOption: async (...args) => {
    calls.create.push({ args });
    if (mockState.throwOnCreate) throw new Error('SQL ERROR: SELECT * FROM secret_table WHERE password = "leak"');
    return { id: 1, min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro', ingreso_minimo: null, ...args[0] };
  },
  updateLoanOption: async (...args) => {
    calls.update.push({ args });
    if (mockState.throwOnUpdate) throw new Error('DB connection lost: password=abc123');
    if (mockState.returnUndefinedOnUpdate) return undefined;
    return { id: Number(args[0]) || 42, ...args[1] };
  },
  deleteLoanOption: async (...args) => {
    calls.delete.push({ args });
    if (mockState.throwOnDelete) throw new Error('FATAL: SQLSTATE[23503] constraint violation');
    if (mockState.returnUndefinedOnDelete) return undefined;
    return { id: Number(args[0]) };
  },
  getAllLoanOptions: async (...args) => {
    calls.getAll.push({ args });
    return [];
  },
};

installMock('../models/loan_option.model', mockModel);

const mockUserModel = {
  findUserById: async (id) => ({ id: 1, name: 'Admin', salario: 5000, categoria: 'Hierro' }),
};

installMock('../models/user.model', mockUserModel);

const controller = require('../controllers/loan_option.controller');

describe('loan-option mutation edge cases (TASK-004-C)', () => {
  beforeEach(() => {
    calls.create.length = 0;
    calls.update.length = 0;
    calls.delete.length = 0;
    calls.getAll.length = 0;
    mockState.throwOnCreate = false;
    mockState.throwOnUpdate = false;
    mockState.throwOnDelete = false;
    mockState.returnUndefinedOnUpdate = false;
    mockState.returnUndefinedOnDelete = false;
  });

  function makeReq(overrides = {}) {
    return {
      user: { id: 1, role: 'admin' },
      body: {},
      params: {},
      ...overrides
    };
  }

  function makeRes() {
    return {
      statusCode: 200,
      body: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      }
    };
  }

  const validBody = { min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro' };

  // ============================================================================
  // C1 — Invalid route IDs reject with 400 + zero model calls
  // ============================================================================

  describe('C1 Invalid route IDs — 400 + zero model calls', () => {
    const invalidIds = [
      { name: 'zero', value: 0 },
      { name: 'negative', value: -1 },
      { name: 'decimal', value: 1.5 },
      { name: 'exponent string', value: '1e2' },
      { name: 'hex string', value: '0x10' },
      { name: 'blank string', value: '' },
      { name: 'whitespace string', value: '   ' },
      { name: 'trailing chars', value: '123abc' },
      { name: 'leading zero + chars', value: '007abc' },
      { name: 'non-safe integer', value: Number.MAX_SAFE_INTEGER + 1 },
      { name: 'boolean true', value: true },
      { name: 'boolean false', value: false },
      { name: 'array', value: [1] },
      { name: 'object', value: { id: 1 } },
    ];

    for (const { name, value } of invalidIds) {
      test(`update with ${name} -> 400 + zero update calls`, async () => {
        const req = makeReq({ params: { id: value }, body: validBody });
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
        assert.equal(calls.create.length, 0, 'create calls must be 0');
      });

      test(`delete with ${name} -> 400 + zero delete calls`, async () => {
        const req = makeReq({ params: { id: value } });
        const res = makeRes();
        await controller.deleteLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.delete.length, 0, 'delete calls must be 0');
      });
    }

    test('update with undefined params.id -> 400 + zero model calls', async () => {
      const req = makeReq({ params: {}, body: validBody });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 400);
      assert.deepEqual(res.body, { error: 'Datos inválidos' });
      assert.equal(calls.update.length, 0);
    });

    test('delete with undefined params.id -> 400 + zero model calls', async () => {
      const req = makeReq({ params: {} });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 400);
      assert.deepEqual(res.body, { error: 'Datos inválidos' });
      assert.equal(calls.delete.length, 0);
    });
  });

  // ============================================================================
  // C1+C3 — Invalid ID must not reach payload validation or persistence
  // ============================================================================

  describe('C1+C3 — Invalid ID precedes payload validation', () => {
    test('update invalid ID + invalid body -> 400 from ID check, zero model calls', async () => {
      const req = makeReq({ params: { id: '0' }, body: { min_amount: 'invalid' } });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 400);
      assert.deepEqual(res.body, { error: 'Datos inválidos' });
      assert.equal(calls.update.length, 0);
    });

    test('delete invalid ID -> 400, zero delete calls (no payload needed)', async () => {
      const req = makeReq({ params: { id: '-5' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 400);
      assert.equal(calls.delete.length, 0);
    });
  });

  // ============================================================================
  // C2 — Valid ID normalization
  // ============================================================================

  describe('C2 Valid ID normalization', () => {
    test('update with "0007" -> model receives numeric 7', async () => {
      const req = makeReq({ params: { id: '0007' }, body: validBody });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.update.length, 1);
      assert.equal(calls.update[0].args[0], 7);
    });

    test('update with 42 (number) -> model receives 42', async () => {
      const req = makeReq({ params: { id: 42 }, body: validBody });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.update.length, 1);
      assert.equal(calls.update[0].args[0], 42);
    });

    test('delete with "0007" -> model receives numeric 7', async () => {
      const req = makeReq({ params: { id: '0007' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.delete.length, 1);
      assert.equal(calls.delete[0].args[0], 7);
    });

    test('delete with 99 (number) -> model receives 99', async () => {
      const req = makeReq({ params: { id: 99 } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.delete.length, 1);
      assert.equal(calls.delete[0].args[0], 99);
    });
  });

  // ============================================================================
  // C4 — Missing record returns 404
  // ============================================================================

  describe('C4 Missing record -> 404', () => {
    test('update nonexistent option -> 404', async () => {
      mockState.returnUndefinedOnUpdate = true;
      const req = makeReq({ params: { id: '42' }, body: validBody });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 404);
      assert.deepEqual(res.body, { error: 'Opción no encontrada' });
      assert.equal(calls.update.length, 1);
    });

    test('delete nonexistent option -> 404', async () => {
      mockState.returnUndefinedOnDelete = true;
      const req = makeReq({ params: { id: '999' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 404);
      assert.deepEqual(res.body, { error: 'Opción no encontrada' });
      assert.equal(calls.delete.length, 1);
    });
  });

  // ============================================================================
  // C5 — Model errors -> 500 generic, no detail leakage
  // ============================================================================

  describe('C5 Model errors -> 500 Error interno', () => {
    test('create model throws SQL text -> 500 Error interno, no detail', async () => {
      mockState.throwOnCreate = true;
      const req = makeReq({ body: validBody });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 500);
      assert.deepEqual(res.body, { error: 'Error interno' });
      assert.ok(!JSON.stringify(res.body).includes('SQL'), 'must not leak SQL');
      assert.ok(!JSON.stringify(res.body).includes('secret'), 'must not leak secret');
      assert.equal(calls.create.length, 1);
    });

    test('update model throws -> 500 Error interno, no detail', async () => {
      mockState.throwOnUpdate = true;
      const req = makeReq({ params: { id: '1' }, body: validBody });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 500);
      assert.deepEqual(res.body, { error: 'Error interno' });
      assert.ok(!JSON.stringify(res.body).includes('password'), 'must not leak password');
      assert.equal(calls.update.length, 1);
    });

    test('delete model throws -> 500 Error interno, no detail', async () => {
      mockState.throwOnDelete = true;
      const req = makeReq({ params: { id: '1' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 500);
      assert.deepEqual(res.body, { error: 'Error interno' });
      assert.ok(!JSON.stringify(res.body).includes('SQLSTATE'), 'must not leak SQLSTATE');
      assert.equal(calls.delete.length, 1);
    });
  });

  // ============================================================================
  // C6 — Auth precedence: non-admin + malformed ID -> 403, zero model calls
  // ============================================================================

  describe('C6 Auth precedence', () => {
    test('non-admin + invalid ID -> 403, zero model calls', async () => {
      const req = makeReq({ user: { id: 2, role: 'user' }, params: { id: '0' }, body: validBody });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.update.length, 0);
    });

    test('missing user + invalid ID -> 403, zero model calls', async () => {
      const req = makeReq({ user: undefined, params: { id: '-1' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.delete.length, 0);
    });

    test('non-admin + valid ID + invalid body -> 403, zero model calls', async () => {
      const req = makeReq({ user: { id: 2, role: 'cliente' }, params: { id: '5' }, body: { min_amount: 'bad' } });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.equal(calls.update.length, 0);
    });
  });

  // ============================================================================
  // C7 — Successful operations preserved
  // ============================================================================

  describe('C7 Successful operations', () => {
    test('valid create -> 201 + one create call', async () => {
      const req = makeReq({ body: validBody });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1);
      assert.ok(res.body, 'response body present');
      assert.equal(typeof res.body.id, 'number');
    });

    test('valid update -> 200 + one update call + correct ID', async () => {
      const req = makeReq({ params: { id: '10' }, body: validBody });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.update.length, 1);
      assert.equal(calls.update[0].args[0], 10);
      assert.ok(res.body, 'response body present');
    });

    test('valid delete -> 200 + one delete call + correct ID', async () => {
      const req = makeReq({ params: { id: '10' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.deepEqual(res.body, { success: true });
      assert.equal(calls.delete.length, 1);
      assert.equal(calls.delete[0].args[0], 10);
    });

    test('valid create with string numbers -> normalized', async () => {
      const req = makeReq({
        body: { min_amount: '1000', max_amount: '5000', interest: '12', months: '6', categoria_minima: 'plata' }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      const data = calls.create[0].args[0];
      assert.equal(typeof data.min_amount, 'number');
      assert.equal(data.categoria_minima, 'Plata');
    });

    test('valid update with defaults (null category, absent income) -> 200', async () => {
      const req = makeReq({
        params: { id: '3' },
        body: { min_amount: 500, max_amount: 3000, interest: 10, months: 3 }
      });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      const data = calls.update[0].args[1];
      assert.equal(data.categoria_minima, 'Hierro');
      assert.equal(data.ingreso_minimo, null);
    });
  });
});
