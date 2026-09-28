'use strict';

const assert = require('node:assert/strict');
const { beforeEach, test } = require('node:test');

function installMock(request, exports) {
  const filename = require.resolve(request);
  require.cache[filename] = {
    id: filename,
    filename,
    loaded: true,
    exports,
  };
}

// Shared state objects — mock functions read from these, so we can mutate them in beforeEach
// without reinstalling mocks (which would break the controller's cached references).
const dbState = {
  queries: [],
};
const loanState = {
  payloads: [],
};

let queryImpl;

// Shared state for user mock
const userState = {
  name: 'DB User',
  categoria: 'Hierro',
  salario: '5000',
};

const fakeDb = {
  async query(sql, params) {
    dbState.queries.push({ sql: String(sql), params });
    return queryImpl(sql, params);
  },
};

installMock('../db', fakeDb);

installMock('../models/loan_installment.model', {
  createInstallmentsForLoan: async () => ({ created: 0 }),
  getInstallmentsByLoan: async () => [],
  updateInstallmentStatus: async () => null,
  getActiveLoansWithAggregates: async () => [],
  markOverdueInstallments: async () => ({ updated: 0 }),
  getLoanProgress: async () => ({}),
  logInstallmentChange: async () => {},
  markInstallmentReported: async () => null,
});

installMock('../models/notification.model', {
  createNotification: async () => null,
});

installMock('../services/notifier', {
  notifyDocumentStatusCodeChange: async () => {},
  notifyLoanStatusChange: async () => {},
});

installMock('../services/push', {
  sendPushToUser: async () => {},
});

// User mock — functions read from userState, so mutating state works without reinstalling
installMock('../models/user.model', {
  findUserById: async (userId) => {
    if (userState._returnNull) return null;
    if (userState._throw) throw new Error('User lookup failed');
    return {
      id: userId,
      name: userState.name,
      categoria: userState.categoria,
      salario: userState.salario,
    };
  },
  incrementPrestamosAprobadosAndUpdateCategoria: async () => ({ prestamos: 1, categoria: 'Plata' }),
  findUserByEmail: async () => null,
  findUserByCedula: async () => null,
  listAdmins: async () => [],
});

// Loan request mock — functions read from loanState
installMock('../models/loan_request.model', {
  createLoanRequest: async (payload) => {
    loanState.payloads.push(payload);
    if (loanState._throwAfterOne) throw new Error('Insert rejected');
    return { id: 99, user_id: payload.userId, user_name: payload.userName, amount: payload.amount, months: payload.months, interest: payload.interest, purpose: payload.purpose, status: 'pendiente', created_at: new Date().toISOString() };
  },
  getAllLoanRequests: async () => [],
  getLoanRequestsByUser: async () => [],
  updateLoanRequestStatus: async () => null,
  signLoanRequest: async () => ({ id: 1, user_id: 7, status: 'pendiente', signature_data: 'sig' }),
});

// Option mock (via db query)
const optionState = {
  row: { id: 1, min_amount: '1000.00', max_amount: '10000.00', interest: '12.00', months: 12, categoria_minima: 'Hierro', ingreso_minimo: null },
  throwError: false,
};

function resetState() {
  dbState.queries = [];
  loanState.payloads = [];
  queryImpl = async () => ({ rows: [], rowCount: 0 });
  userState.name = 'DB User';
  userState.categoria = 'Hierro';
  userState.salario = '5000';
  optionState.row = { id: 1, min_amount: '1000.00', max_amount: '10000.00', interest: '12.00', months: 12, categoria_minima: 'Hierro', ingreso_minimo: null };
  optionState.throwError = false;
  userState._returnNull = false;
  userState._throw = false;
  loanState._throwAfterOne = false;
}

function responseMock() {
  return {
    statusCode: 200,
    body: undefined,
    headersSent: false,
    headers: {},
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; this.headersSent = true; return this; },
    setHeader(name, value) { this.headers[String(name).toLowerCase()] = value; },
    send(body) { this.body = body; this.headersSent = true; return this; },
  };
}

function makeReq(body) {
  return { body: body || {}, user: { id: 7, name: 'Stale JWT Name', role: 'cliente' } };
}

beforeEach(() => {
  resetState();
});

// Import controller AFTER all mocks are installed but BEFORE beforeEach runs.
// Controller captures function references, but those functions read from shared state,
// so mutating state in beforeEach works correctly.
const { createLoanRequestController } = require('../controllers/loan_request.controller');

test('valid request uses option terms and persists database user name', async () => {
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: '5000', purpose: 'Compra casa', loan_option_id: '1' }), res);
  assert.equal(res.statusCode, 201);
  assert.equal(res.body.status, 'pendiente');
  assert.equal(res.body.user_name, 'DB User');
  assert.equal(loanState.payloads.length, 1);
  const p = loanState.payloads[0];
  assert.equal(p.userName, 'DB User');
  assert.equal(p.amount, 5000);
  assert.equal(p.months, 12);
  assert.equal(p.interest, 12);
  assert.equal(p.purpose, 'Compra casa');
  assert.equal(p.userId, 7);
  assert.equal(dbState.queries.length, 1);
});

test('omitted body months and interest succeed using option terms', async () => {
  optionState.row = { id: 1, min_amount: '1000', max_amount: '10000', interest: '5', months: 6, categoria_minima: 'Hierro', ingreso_minimo: null };
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 2000, purpose: 'Auto', loan_option_id: 1 }), res);
  assert.equal(res.statusCode, 201);
  assert.equal(res.body.months, 6);
  assert.equal(res.body.interest, 5);
  assert.equal(loanState.payloads[0].months, 6);
  assert.equal(loanState.payloads[0].interest, 5);
});

test('mismatched body months/interest are ignored', async () => {
  optionState.row = { id: 1, min_amount: '1000', max_amount: '10000', interest: '3', months: 24, categoria_minima: 'Hierro', ingreso_minimo: null };
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 3000, purpose: 'Vacaciones', loan_option_id: 1, months: 99, interest: 999 }), res);
  assert.equal(res.statusCode, 201);
  assert.equal(loanState.payloads[0].months, 24);
  assert.equal(loanState.payloads[0].interest, 3);
});

test('exact min/max amounts accepted; zero interest accepted; numeric strings accepted', async () => {
  optionState.row = { id: 1, min_amount: '500', max_amount: '500', interest: '0', months: 3, categoria_minima: 'Hierro', ingreso_minimo: null };
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: '500', purpose: 'Test', loan_option_id: 1 }), res);
  assert.equal(res.statusCode, 201);
  assert.strictEqual(res.body.amount, 500);
  assert.strictEqual(res.body.interest, 0);
  assert.strictEqual(loanState.payloads[0].months, 3);
});

test('invalid loan_option_id missing returns 400 with zero persistence', async () => {
  queryImpl = async () => ({ rows: [], rowCount: 0 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 10000, purpose: 'X', loan_option_id: '' }), res);
  assert.equal(res.statusCode, 400);
  assert.equal(loanState.payloads.length, 0);
});

test('invalid loan_option_id boolean/array/object returns 400', async () => {
  queryImpl = async () => ({ rows: [], rowCount: 0 });
  for (const val of [true, false, [1], { id: 1 }]) {
    const res = responseMock();
    await createLoanRequestController(makeReq({ amount: 1000, purpose: 'X', loan_option_id: val }), res);
    assert.equal(res.statusCode, 400, `Failed for ${JSON.stringify(val)}`);
  }
  assert.equal(loanState.payloads.length, 0);
});

test('invalid loan_option_id zero/negative/fractional/unsafe/exponent/hex/trailing returns 400', async () => {
  queryImpl = async () => ({ rows: [{ id: 1, min_amount: '1', max_amount: '10', interest: '1', months: 1, categoria_minima: 'Hierro', ingreso_minimo: null }], rowCount: 1 });
  for (const val of [0, -5, 1.5, 9007199254740992, '1e5', '0x10', '123abc', '123 ', ' 4', '4 ']) {
    const res = responseMock();
    await createLoanRequestController(makeReq({ amount: 5, purpose: 'X', loan_option_id: val }), res);
    assert.equal(res.statusCode, 400, `Expected 400 for ${JSON.stringify(val)}`);
    assert.equal(loanState.payloads.length, 0, `Zero persistence for ${JSON.stringify(val)}`);
  }
});

test('missing loan option returns 400 with zero persistence', async () => {
  queryImpl = async () => ({ rows: [], rowCount: 0 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 1000, purpose: 'X', loan_option_id: 999 }), res);
  assert.equal(res.statusCode, 400);
  assert.equal(loanState.payloads.length, 0);
});

test('invalid purpose (non-string or empty after trim) returns 400', async () => {
  queryImpl = async () => ({ rows: [{ id: 1, min_amount: '1', max_amount: '100', interest: '1', months: 1, categoria_minima: 'Hierro', ingreso_minimo: null }], rowCount: 1 });
  for (const c of [{ value: 123 }, { value: '' }, { value: '   ' }, { value: null }, { value: {} }, { value: [] }]) {
    const res = responseMock();
    await createLoanRequestController(makeReq({ amount: 2000, purpose: c.value, loan_option_id: 1 }), res);
    assert.equal(res.statusCode, 400, `Purpose case: ${String(c.value)}`);
  }
  assert.equal(loanState.payloads.length, 0);
});

test('invalid amount types and out-of-range amount return 400', async () => {
  queryImpl = async () => ({ rows: [{ id: 1, min_amount: '1000', max_amount: '10000', interest: '1', months: 1, categoria_minima: 'Hierro', ingreso_minimo: null }], rowCount: 1 });
  for (const a of [0, -100, 'notanumber', '', true, {}, [], 50000]) {
    const res = responseMock();
    await createLoanRequestController(makeReq({ amount: a, purpose: 'X', loan_option_id: 1 }), res);
    assert.equal(res.statusCode, 400, `Amount: ${JSON.stringify(a)}`);
  }
  assert.equal(loanState.payloads.length, 0);
});

test('missing user returns 404 with zero persistence', async () => {
  userState._returnNull = true;
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 2000, purpose: 'X', loan_option_id: 1 }), res);
  assert.equal(res.statusCode, 404);
  assert.equal(loanState.payloads.length, 0);
});

test('category normalization/defaults and insufficient/unknown categories', async () => {
  // Unknown user category -> 403
  userState.categoria = 'desconocida';
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res403 = responseMock();
  await createLoanRequestController(makeReq({ amount: 2000, purpose: 'X', loan_option_id: 1 }), res403);
  assert.equal(res403.statusCode, 403);

  // Unknown option category -> 500
  userState.categoria = 'Hierro';
  const badOptionCat = { id: 1, min_amount: '1', max_amount: '100', interest: '1', months: 1, categoria_minima: 'desconocida', ingreso_minimo: null };
  queryImpl = async () => ({ rows: [badOptionCat], rowCount: 1 });
  const res500 = responseMock();
  await createLoanRequestController(makeReq({ amount: 10, purpose: 'X', loan_option_id: 1 }), res500);
  assert.equal(res500.statusCode, 500);

  // User category below minimum -> 403
  userState.categoria = 'plata';
  const oroOption = { id: 1, min_amount: '1', max_amount: '100', interest: '1', months: 1, categoria_minima: 'Oro', ingreso_minimo: null };
  queryImpl = async () => ({ rows: [oroOption], rowCount: 1 });
  const resBelow = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resBelow);
  assert.equal(resBelow.statusCode, 403);

  // Null/blank user category defaults to Hierro and succeeds
  userState.categoria = null;
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const resDefault = responseMock();
  await createLoanRequestController(makeReq({ amount: 2000, purpose: 'X', loan_option_id: 1 }), resDefault);
  assert.equal(resDefault.statusCode, 201);
});

test('income validation: null permits missing salary, zero validates salary, exact threshold, missing/invalid/negative/insufficient returns 403', async () => {
  // ingreso_minimo null -> no validation, missing salary allowed
  const nullIncomeOption = { id: 1, min_amount: '1', max_amount: '100', interest: '1', months: 1, categoria_minima: 'Hierro', ingreso_minimo: null };
  queryImpl = async () => ({ rows: [nullIncomeOption], rowCount: 1 });
  const resNull = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resNull);
  assert.equal(resNull.statusCode, 201);

  // ingreso_minimo 0 -> validates salary; exact 0 accepted
  const zeroThresholdOption = { id: 1, min_amount: '1', max_amount: '100', interest: '1', months: 1, categoria_minima: 'Hierro', ingreso_minimo: 0 };
  queryImpl = async () => ({ rows: [zeroThresholdOption], rowCount: 1 });
  userState.salario = 0;
  const resZero = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resZero);
  assert.equal(resZero.statusCode, 201);

  // ingreso_minimo 3000 -> exact threshold accepted
  const exactOption = { id: 1, min_amount: '1', max_amount: '100', interest: '1', months: 1, categoria_minima: 'Hierro', ingreso_minimo: '3000' };
  queryImpl = async () => ({ rows: [exactOption], rowCount: 1 });
  userState.salario = '3000';
  const resExact = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resExact);
  assert.equal(resExact.statusCode, 201);

  // Missing salary with threshold -> 403
  const incomeOption = { id: 1, min_amount: '1', max_amount: '100', interest: '1', months: 1, categoria_minima: 'Hierro', ingreso_minimo: 100 };
  queryImpl = async () => ({ rows: [incomeOption], rowCount: 1 });
  userState.salario = null;
  const resMissing = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resMissing);
  assert.equal(resMissing.statusCode, 403);

  // Negative salary -> 403
  userState.salario = -500;
  const resNeg = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resNeg);
  assert.equal(resNeg.statusCode, 403);

  // Invalid salary type -> 403
  userState.salario = {};
  const resInvalid = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resInvalid);
  assert.equal(resInvalid.statusCode, 403);

  // Insufficient salary -> 403
  userState.salario = '50';
  const resInsuf = responseMock();
  await createLoanRequestController(makeReq({ amount: 50, purpose: 'X', loan_option_id: 1 }), resInsuf);
  assert.equal(resInsuf.statusCode, 403);
});

test('corrupt option configuration returns 500 with zero persistence', async () => {
  const corruptConfigs = [
    { label: 'bad min_amount', row: { id: 1, min_amount: null, max_amount: '100', interest: '5', months: 12, categoria_minima: 'Hierro', ingreso_minimo: null } },
    { label: 'bad max_amount <=0', row: { id: 1, min_amount: '1', max_amount: '-1', interest: '5', months: 12, categoria_minima: 'Hierro', ingreso_minimo: null } },
    { label: 'max_amount < min_amount', row: { id: 1, min_amount: '10', max_amount: '5', interest: '5', months: 12, categoria_minima: 'Hierro', ingreso_minimo: null } },
    { label: 'bad interest negative', row: { id: 1, min_amount: '1', max_amount: '100', interest: '-1', months: 12, categoria_minima: 'Hierro', ingreso_minimo: null } },
    { label: 'bad months zero', row: { id: 1, min_amount: '1', max_amount: '100', interest: '5', months: 0, categoria_minima: 'Hierro', ingreso_minimo: null } },
    { label: 'bad ingreso_minimo empty string', row: { id: 1, min_amount: '1', max_amount: '100', interest: '5', months: 12, categoria_minima: 'Hierro', ingreso_minimo: '' } },
  ];
  for (const cfg of corruptConfigs) {
    userState.categoria = 'Hierro';
    userState.salario = '5000';
    queryImpl = async () => ({ rows: [cfg.row], rowCount: 1 });
    const res = responseMock();
    await createLoanRequestController(makeReq({ amount: 5, purpose: 'X', loan_option_id: 1 }), res);
    assert.equal(res.statusCode, 500, `Failed for: ${cfg.label}`);
    assert.equal(loanState.payloads.length, 0, `Zero persistence for: ${cfg.label}`);
  }
});

test('option lookup failure produces 500 with zero persistence', async () => {
  queryImpl = async () => { throw new Error('DB down'); };
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 2000, purpose: 'X', loan_option_id: 1 }), res);
  assert.equal(res.statusCode, 500);
  assert.equal(loanState.payloads.length, 0);
});

test('user lookup failure produces 500 with zero persistence', async () => {
  userState._throw = true;
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 2000, purpose: 'X', loan_option_id: 1 }), res);
  assert.equal(res.statusCode, 500);
  assert.equal(loanState.payloads.length, 0);
});

test('insert rejection produces 500 with exactly one persistence attempt', async () => {
  loanState._throwAfterOne = true;
  queryImpl = async () => ({ rows: [optionState.row], rowCount: 1 });
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 5000, purpose: 'X', loan_option_id: 1 }), res);
  assert.equal(res.statusCode, 500);
  assert.equal(loanState.payloads.length, 1);
});

test('responses must not expose internal error details', async () => {
  queryImpl = async () => { throw new Error('SQL ERROR: SELECT * FROM secret_table WHERE password = "leak"'); };
  const res = responseMock();
  await createLoanRequestController(makeReq({ amount: 2000, purpose: 'X', loan_option_id: 1 }), res);
  assert.equal(res.statusCode, 500);
  assert.equal(typeof res.body, 'object');
  assert.equal(typeof res.body.error, 'string');
  assert.strictEqual(res.body.error.includes('SQL'), false);
  assert.strictEqual(res.body.error.includes('secret'), false);
});
