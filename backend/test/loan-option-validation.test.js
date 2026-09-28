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
// A1.1 — Shared call-recording state for all four loan-option model functions
// ============================================================================

const calls = {
  create: [],   // each entry: { args: [data] }
  update: [],   // each entry: { args: [id, data] }
  delete: [],   // each entry: { args: [id] }
  getAll: [],   // each entry: { args: [{ salarioMinimo }] }
};

// A1.1 — Shared mock model with call recording
const mockModel = {
  createLoanOption: async (...args) => {
    calls.create.push({ args });
    return { id: 1, min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro', ingreso_minimo: null, ...args[0] };
  },
  updateLoanOption: async (...args) => {
    calls.update.push({ args });
    return { id: Number(args[0]) || 42, ...args[1] };
  },
  deleteLoanOption: async (...args) => {
    calls.delete.push({ args });
    return { success: true };
  },
  getAllLoanOptions: async (...args) => {
    calls.getAll.push({ args });
    return [];
  },
};

installMock('../models/loan_option.model', mockModel);

// Mock user model
const mockUserModel = {
  findUserById: async (id) => ({ id: 1, name: 'Admin', salario: 5000, categoria: 'Hierro' }),
};

installMock('../models/user.model', mockUserModel);

// Now require the controller (after mocks are installed)
const controller = require('../controllers/loan_option.controller');

describe('loan-option create/update validation', () => {

  // A1.2 — Reset every call record before each test
  beforeEach(() => {
    calls.create.length = 0;
    calls.update.length = 0;
    calls.delete.length = 0;
    calls.getAll.length = 0;
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

  // ============================================================================
  // A1.3 — Authorization precedence with zero call assertions
  // ============================================================================

  describe('A1.3 Authorization precedence — zero mutation calls', () => {
    test('missing user create -> 403, zero create/update/delete calls', async () => {
      const req = makeReq({ user: undefined });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.create.length, 0, 'create calls must be 0');
      assert.equal(calls.update.length, 0, 'update calls must be 0');
      assert.equal(calls.delete.length, 0, 'delete calls must be 0');
    });

    test('non-admin create -> 403, zero create/update/delete calls', async () => {
      const req = makeReq({ user: { id: 2, role: 'user' }, body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 6 } });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.create.length, 0, 'create calls must be 0');
      assert.equal(calls.update.length, 0, 'update calls must be 0');
      assert.equal(calls.delete.length, 0, 'delete calls must be 0');
    });

    test('missing user update -> 403, zero update calls', async () => {
      const req = makeReq({ user: undefined, params: { id: '1' }, body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 6 } });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.create.length, 0, 'create calls must be 0');
      assert.equal(calls.update.length, 0, 'update calls must be 0');
    });

    test('non-admin update -> 403, zero update calls', async () => {
      const req = makeReq({ user: { id: 2, role: 'user' }, params: { id: '1' }, body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 6 } });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.update.length, 0, 'update calls must be 0');
    });

    test('missing user delete -> 403, zero delete calls', async () => {
      const req = makeReq({ user: undefined, params: { id: '1' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.delete.length, 0, 'delete calls must be 0');
    });

    test('non-admin delete -> 403, zero delete calls', async () => {
      const req = makeReq({ user: { id: 2, role: 'user' }, params: { id: '1' } });
      const res = makeRes();
      await controller.deleteLoanOptionController(req, res);
      assert.equal(res.statusCode, 403);
      assert.deepEqual(res.body, { error: 'No autorizado' });
      assert.equal(calls.delete.length, 0, 'delete calls must be 0');
    });

    test('admin GET -> 200, one getAll call', async () => {
      const req = makeReq({ user: { id: 1, role: 'admin' } });
      const res = makeRes();
      await controller.getAllLoanOptionsController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.getAll.length, 1, 'getAll calls must be 1');
    });
  });

  // ============================================================================
  // A1.4 — Invalid create payload: 400 + zero create calls
  // ============================================================================

  describe('A1.4 Invalid create payload — 400 + zero create calls', () => {
    const validBase = { min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro' };

    const rejectedNumericValues = [
      { name: 'boolean true', value: true },
      { name: 'boolean false', value: false },
      { name: 'null', value: null },
      { name: 'undefined', value: undefined },
      { name: 'array', value: [] },
      { name: 'object', value: {} },
      { name: 'blank string', value: '' },
      { name: 'whitespace string', value: '   ' },
      { name: 'NaN', value: NaN },
      { name: 'Infinity', value: Infinity },
      { name: '-Infinity', value: -Infinity },
      { name: 'hex 0x10', value: '0x10' },
      { name: 'exponent 1e5', value: '1e5' },
      { name: 'trailing chars 123abc', value: '123abc' },
      { name: 'trailing decimal .', value: '123.' },
      { name: 'leading decimal .', value: '.123' },
      { name: 'multiple dots', value: '1.2.3' },
    ];

    const numericFields = ['min_amount', 'max_amount', 'interest'];

    for (const field of numericFields) {
      for (const { name, value } of rejectedNumericValues) {
        test(`create ${field}: ${name} -> 400 + zero create calls`, async () => {
          const req = makeReq({ body: { ...validBase, [field]: value } });
          const res = makeRes();
          await controller.createLoanOptionController(req, res);
          assert.equal(res.statusCode, 400);
          assert.deepEqual(res.body, { error: 'Datos inválidos' });
          assert.equal(calls.create.length, 0, 'create calls must be 0');
        });
      }
    }

    // Boundary violations
    const boundaryCases = [
      { name: 'min_amount < 0', body: { min_amount: -1, max_amount: 5000, interest: 12, months: 6 } },
      { name: 'max_amount = 0', body: { min_amount: 0, max_amount: 0, interest: 12, months: 6 } },
      { name: 'max_amount < min_amount', body: { min_amount: 5000, max_amount: 1000, interest: 12, months: 6 } },
      { name: 'interest < 0', body: { min_amount: 0, max_amount: 5000, interest: -1, months: 6 } },
      { name: 'months = 0', body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 0 } },
      { name: 'months negative', body: { min_amount: 1000, max_amount: 5000, interest: 12, months: -1 } },
      { name: 'months non-integer float', body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 1.5 } },
      { name: 'months non-safe integer', body: { min_amount: 1000, max_amount: 5000, interest: 12, months: Number.MAX_SAFE_INTEGER + 1 } },
      { name: 'months non-digit string', body: { min_amount: 1000, max_amount: 5000, interest: 12, months: '12a' } },
    ];

    for (const { name, body } of boundaryCases) {
      test(`create ${name} -> 400 + zero create calls`, async () => {
        const req = makeReq({ body });
        const res = makeRes();
        await controller.createLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.create.length, 0, 'create calls must be 0');
      });
    }

    // Invalid category
    const invalidCategories = ['Bronce', 'PLATINUM', 'Oroo', 123, []];
    for (const input of invalidCategories) {
      test(`create invalid category ${JSON.stringify(input)} -> 400 + zero create calls`, async () => {
        const req = makeReq({ body: { ...validBase, categoria_minima: input } });
        const res = makeRes();
        await controller.createLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.create.length, 0, 'create calls must be 0');
      });
    }

    // Invalid ingreso_minimo
    const invalidIngresos = [
      { name: 'negative ingreso_minimo', value: -1 },
      { name: 'invalid ingreso_minimo string', value: 'abc' },
    ];
    for (const { name, value } of invalidIngresos) {
      test(`create ${name} -> 400 + zero create calls`, async () => {
        const req = makeReq({ body: { ...validBase, ingreso_minimo: value } });
        const res = makeRes();
        await controller.createLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.create.length, 0, 'create calls must be 0');
      });
    }
  });

  // ============================================================================
  // A1.5 — Invalid update payload: 400 + zero update calls (each validation family)
  // ============================================================================

  describe('A1.5 Invalid update payload — 400 + zero update calls', () => {
    const validBase = { min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro' };
    const makeUpdateReq = (body) => makeReq({ params: { id: '42' }, body });

    // A1.5 — Type rejection (one representative per rejected class)
    const typeRejectionCases = [
      { name: 'boolean', body: { ...validBase, min_amount: true } },
      { name: 'null', body: { ...validBase, max_amount: null } },
      { name: 'undefined', body: { ...validBase, interest: undefined } },
      { name: 'array', body: { ...validBase, min_amount: [] } },
      { name: 'object', body: { ...validBase, max_amount: {} } },
    ];
    for (const { name, body } of typeRejectionCases) {
      test(`update type rejection: ${name} -> 400 + zero update calls`, async () => {
        const req = makeUpdateReq(body);
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
      });
    }

    // A1.5 — Malformed numeric string
    const malformedStringCases = [
      { name: 'hex', body: { ...validBase, min_amount: '0x10' } },
      { name: 'exponent', body: { ...validBase, max_amount: '1e5' } },
      { name: 'trailing chars', body: { ...validBase, interest: '12abc' } },
      { name: 'blank string', body: { ...validBase, min_amount: '' } },
    ];
    for (const { name, body } of malformedStringCases) {
      test(`update malformed string: ${name} -> 400 + zero update calls`, async () => {
        const req = makeUpdateReq(body);
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
      });
    }

    // A1.5 — Non-finite number
    const nonFiniteCases = [
      { name: 'NaN', body: { ...validBase, min_amount: NaN } },
      { name: 'Infinity', body: { ...validBase, max_amount: Infinity } },
    ];
    for (const { name, body } of nonFiniteCases) {
      test(`update non-finite: ${name} -> 400 + zero update calls`, async () => {
        const req = makeUpdateReq(body);
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
      });
    }

    // A1.5 — Invalid boundary/relation
    const boundaryCases = [
      { name: 'min_amount < 0', body: { ...validBase, min_amount: -1 } },
      { name: 'max_amount <= 0', body: { ...validBase, max_amount: 0 } },
      { name: 'max_amount < min_amount', body: { min_amount: 5000, max_amount: 1000, interest: 12, months: 6, categoria_minima: 'Hierro' } },
      { name: 'interest < 0', body: { ...validBase, interest: -1 } },
    ];
    for (const { name, body } of boundaryCases) {
      test(`update boundary: ${name} -> 400 + zero update calls`, async () => {
        const req = makeUpdateReq(body);
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
      });
    }

    // A1.5 — Invalid months
    const monthsCases = [
      { name: 'months = 0', body: { ...validBase, months: 0 } },
      { name: 'months negative', body: { ...validBase, months: -1 } },
      { name: 'months float', body: { ...validBase, months: 1.5 } },
      { name: 'months non-safe', body: { ...validBase, months: Number.MAX_SAFE_INTEGER + 1 } },
      { name: 'months non-digit string', body: { ...validBase, months: '12a' } },
    ];
    for (const { name, body } of monthsCases) {
      test(`update months: ${name} -> 400 + zero update calls`, async () => {
        const req = makeUpdateReq(body);
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
      });
    }

    // A1.5 — Invalid category
    const categoryCases = ['Bronce', 'PLATINUM', 'Oroo', 123, []];
    for (const input of categoryCases) {
      test(`update invalid category ${JSON.stringify(input)} -> 400 + zero update calls`, async () => {
        const req = makeUpdateReq({ ...validBase, categoria_minima: input });
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
      });
    }

    // A1.5 — Invalid income
    const incomeCases = [
      { name: 'negative income', body: { ...validBase, ingreso_minimo: -1 } },
      { name: 'invalid income string', body: { ...validBase, ingreso_minimo: 'abc' } },
    ];
    for (const { name, body } of incomeCases) {
      test(`update income: ${name} -> 400 + zero update calls`, async () => {
        const req = makeUpdateReq(body);
        const res = makeRes();
        await controller.updateLoanOptionController(req, res);
        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.body, { error: 'Datos inválidos' });
        assert.equal(calls.update.length, 0, 'update calls must be 0');
      });
    }
  });

  // ============================================================================
  // A1.6 — Positive create: exact normalized arguments + one call
  // ============================================================================

  describe('A1.6 Positive create — one call + exact normalized arguments', () => {
    test('create with decimal strings "1000.50", "5000", "12.25", "6", "plata", "50000" -> one call + canonical Plata', async () => {
      const req = makeReq({
        body: {
          min_amount: '1000.50',
          max_amount: '5000',
          interest: '12.25',
          months: '6',
          categoria_minima: 'plata',
          ingreso_minimo: '50000'
        }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1, 'exactly one create call');
      const data = calls.create[0].args[0];
      assert.equal(typeof data.min_amount, 'number');
      assert.equal(data.min_amount, 1000.50);
      assert.equal(typeof data.max_amount, 'number');
      assert.equal(data.max_amount, 5000);
      assert.equal(typeof data.interest, 'number');
      assert.equal(data.interest, 12.25);
      assert.equal(typeof data.months, 'number');
      assert.equal(data.months, 6);
      assert.equal(data.categoria_minima, 'Plata');
      assert.equal(typeof data.ingreso_minimo, 'number');
      assert.equal(data.ingreso_minimo, 50000);
    });

    test('create with absent category defaults to Hierro, absent income -> null', async () => {
      const req = makeReq({
        body: {
          min_amount: 1000,
          max_amount: 5000,
          interest: 12,
          months: 6
        }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1, 'exactly one create call');
      const data = calls.create[0].args[0];
      assert.equal(data.categoria_minima, 'Hierro');
      assert.equal(data.ingreso_minimo, null);
    });

    test('create with null category -> Hierro, null income -> null', async () => {
      const req = makeReq({
        body: {
          min_amount: 1000,
          max_amount: 5000,
          interest: 12,
          months: 6,
          categoria_minima: null,
          ingreso_minimo: null
        }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1, 'exactly one create call');
      const data = calls.create[0].args[0];
      assert.equal(data.categoria_minima, 'Hierro');
      assert.equal(data.ingreso_minimo, null);
    });

    test('create with whitespace category -> Hierro', async () => {
      const req = makeReq({
        body: {
          min_amount: 1000,
          max_amount: 5000,
          interest: 12,
          months: 6,
          categoria_minima: '   '
        }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1, 'exactly one create call');
      assert.equal(calls.create[0].args[0].categoria_minima, 'Hierro');
    });

    test('create with zero min_amount, zero interest, equal min/max -> one call', async () => {
      const req = makeReq({
        body: { min_amount: '0', max_amount: '5000', interest: '0', months: 12 }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1, 'exactly one create call');
      const data = calls.create[0].args[0];
      assert.equal(data.min_amount, 0);
      assert.equal(data.interest, 0);
      assert.equal(data.max_amount, 5000);
      assert.equal(data.months, 12);
    });

    // Case-insensitive category normalization for all valid ranks
    const categoryPairs = [
      { input: 'hierro', expected: 'Hierro' },
      { input: 'HIERRO', expected: 'Hierro' },
      { input: 'plata', expected: 'Plata' },
      { input: 'oro', expected: 'Oro' },
      { input: 'platino', expected: 'Platino' },
      { input: 'diamante', expected: 'Diamante' },
      { input: 'esmeralda', expected: 'Esmeralda' },
    ];
    for (const { input, expected } of categoryPairs) {
      test(`create category case-insensitive: ${input} -> ${expected}`, async () => {
        const req = makeReq({
          body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: input }
        });
        const res = makeRes();
        await controller.createLoanOptionController(req, res);
        assert.equal(res.statusCode, 201);
        assert.equal(calls.create.length, 1, 'exactly one create call');
        assert.equal(calls.create[0].args[0].categoria_minima, expected);
      });
    }
  });

  // ============================================================================
  // A1.6 — Positive update: exact normalized arguments + one call
  // ============================================================================

  describe('A1.6 Positive update — one call + exact normalized arguments', () => {
    test('update with decimal strings and "plata" category -> one call + canonical Plata', async () => {
      const req = makeReq({
        params: { id: '42' },
        body: {
          min_amount: '1000.50',
          max_amount: '5000',
          interest: '12.25',
          months: '6',
          categoria_minima: 'plata',
          ingreso_minimo: '50000'
        }
      });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.update.length, 1, 'exactly one update call');
      const [routeId, data] = calls.update[0].args;
      assert.equal(routeId, 42);
      assert.equal(typeof data.min_amount, 'number');
      assert.equal(data.min_amount, 1000.50);
      assert.equal(typeof data.max_amount, 'number');
      assert.equal(data.max_amount, 5000);
      assert.equal(typeof data.interest, 'number');
      assert.equal(data.interest, 12.25);
      assert.equal(typeof data.months, 'number');
      assert.equal(data.months, 6);
      assert.equal(data.categoria_minima, 'Plata');
      assert.equal(data.ingreso_minimo, 50000);
    });

    test('update with blank category -> Hierro, absent income -> null', async () => {
      const req = makeReq({
        params: { id: '7' },
        body: {
          min_amount: 2000,
          max_amount: 6000,
          interest: 15,
          months: 12,
          categoria_minima: '',
          ingreso_minimo: null
        }
      });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.update.length, 1, 'exactly one update call');
      const [routeId, data] = calls.update[0].args;
      assert.equal(routeId, 7);
      assert.equal(data.categoria_minima, 'Hierro');
      assert.equal(data.ingreso_minimo, null);
    });

    test('update with absent category and absent income -> Hierro and null', async () => {
      const req = makeReq({
        params: { id: '99' },
        body: {
          min_amount: 500,
          max_amount: 3000,
          interest: 10,
          months: 3
        }
      });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.update.length, 1, 'exactly one update call');
      const [routeId, data] = calls.update[0].args;
      assert.equal(routeId, 99);
      assert.equal(data.categoria_minima, 'Hierro');
      assert.equal(data.ingreso_minimo, null);
    });
  });

  // ============================================================================
  // A1.7 — Response body compatibility for successful create/update
  // ============================================================================

  describe('A1.7 Response body from mock return', () => {
    test('successful create returns 201 with mock-created object', async () => {
      const req = makeReq({
        body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Hierro' }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.ok(res.body, 'response body must not be null');
      assert.equal(typeof res.body.id, 'number');
      assert.equal(res.body.min_amount, 1000);
      assert.equal(res.body.max_amount, 5000);
      assert.equal(res.body.interest, 12);
      assert.equal(res.body.months, 6);
      assert.equal(res.body.categoria_minima, 'Hierro');
    });

    test('successful update returns 200 with mock-updated object', async () => {
      const req = makeReq({
        params: { id: '5' },
        body: { min_amount: 2000, max_amount: 8000, interest: 10, months: 24, categoria_minima: 'Oro' }
      });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.ok(res.body, 'response body must not be null');
      assert.equal(res.body.id, 5);
      assert.equal(res.body.min_amount, 2000);
      assert.equal(res.body.max_amount, 8000);
      assert.equal(res.body.interest, 10);
      assert.equal(res.body.months, 24);
      assert.equal(res.body.categoria_minima, 'Oro');
    });
  });

  // ============================================================================
  // A5. Response codes and persistence (preserved, now with call assertions)
  // ============================================================================

  describe('A5 Response codes and persistence', () => {
    test('invalid create payload -> 400 + zero create calls', async () => {
      const req = makeReq({ body: { min_amount: 'invalid', max_amount: 5000, interest: 12, months: 6 } });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 400);
      assert.deepEqual(res.body, { error: 'Datos inválidos' });
      assert.equal(calls.create.length, 0, 'create calls must be 0');
    });

    test('valid create -> 201 + one create call + correct args', async () => {
      const req = makeReq({
        body: { min_amount: 1000, max_amount: 5000, interest: 12, months: 6, categoria_minima: 'Plata', ingreso_minimo: '50000' }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1, 'exactly one create call');
      const data = calls.create[0].args[0];
      assert.equal(data.min_amount, 1000);
      assert.equal(data.max_amount, 5000);
      assert.equal(data.interest, 12);
      assert.equal(data.months, 6);
      assert.equal(data.categoria_minima, 'Plata');
      assert.equal(data.ingreso_minimo, 50000);
    });

    test('valid update -> 200 + one update call + correct args', async () => {
      const req = makeReq({
        params: { id: '42' },
        body: { min_amount: 2000, max_amount: 6000, interest: 15, months: 12, categoria_minima: 'Oro', ingreso_minimo: null }
      });
      const res = makeRes();
      await controller.updateLoanOptionController(req, res);
      assert.equal(res.statusCode, 200);
      assert.equal(calls.update.length, 1, 'exactly one update call');
      const [routeId, data] = calls.update[0].args;
      assert.equal(routeId, 42);
      assert.equal(data.min_amount, 2000);
      assert.equal(data.max_amount, 6000);
      assert.equal(data.interest, 15);
      assert.equal(data.months, 12);
      assert.equal(data.categoria_minima, 'Oro');
      assert.equal(data.ingreso_minimo, null);
    });

    test('valid create with string numbers -> normalized in one create call', async () => {
      const req = makeReq({
        body: { min_amount: '1000', max_amount: '5000', interest: '12', months: '6', categoria_minima: 'Hierro' }
      });
      const res = makeRes();
      await controller.createLoanOptionController(req, res);
      assert.equal(res.statusCode, 201);
      assert.equal(calls.create.length, 1, 'exactly one create call');
      const data = calls.create[0].args[0];
      assert.equal(typeof data.min_amount, 'number');
      assert.equal(typeof data.max_amount, 'number');
      assert.equal(typeof data.interest, 'number');
      assert.equal(typeof data.months, 'number');
      assert.equal(data.min_amount, 1000);
      assert.equal(data.max_amount, 5000);
      assert.equal(data.interest, 12);
      assert.equal(data.months, 6);
    });
  });
});
