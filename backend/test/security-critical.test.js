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

const state = {
  queries: [],
  updateLoanCalls: [],
  incrementCalls: 0,
  installmentCalls: 0,
};

let queryImpl;
let updateLoanImpl;

const fakeDb = {
  async query(sql, params) {
    state.queries.push({ sql: String(sql), params });
    return queryImpl(sql, params);
  },
};

installMock('../db', fakeDb);
installMock('../models/loan_request.model', {
  createLoanRequest: async () => null,
  getAllLoanRequests: async () => [],
  getLoanRequestsByUser: async () => [],
  signLoanRequest: async () => null,
  async updateLoanRequestStatus(...args) {
    state.updateLoanCalls.push(args);
    return updateLoanImpl(...args);
  },
});
installMock('../models/loan_installment.model', {
  getInstallmentsByLoan: async () => [],
  async createInstallmentsForLoan() {
    state.installmentCalls += 1;
    return { created: 0 };
  },
  markInstallmentReported: async () => null,
  updateInstallmentStatus: async () => null,
  getActiveLoansWithAggregates: async () => [],
  markOverdueInstallments: async () => ({ updated: 0 }),
  getLoanProgress: async () => ({}),
});
installMock('../models/loan_installment_log.model', {
  logInstallmentChange: async () => {},
});
installMock('../models/user.model', {
  findUserByEmail: async () => null,
  findUserById: async (id) => ({ id }),
  findUserByCedula: async () => null,
  listAdmins: async () => [],
  async incrementPrestamosAprobadosAndUpdateCategoria() {
    state.incrementCalls += 1;
    return { prestamos: 1, categoria: 'Plata' };
  },
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
installMock('../controllers/upload.controller', {
  sendDocumentEmail: async () => {},
  queueEmailSend: async () => {},
  buildMailContext: () => ({}),
  buildMailPayload: () => ({}),
});

const {
  downloadInstallmentReceipt,
} = require('../controllers/loan_installment.controller');
const {
  updateUserDocumentStatus,
} = require('../controllers/document_status.controller');
const {
  updateLoanRequestStatusController,
} = require('../controllers/loan_request.controller');

function responseMock() {
  return {
    statusCode: 200,
    body: undefined,
    headers: {},
    headersSent: false,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      this.headersSent = true;
      return this;
    },
    setHeader(name, value) {
      this.headers[String(name).toLowerCase()] = value;
    },
    send(body) {
      this.body = body;
      this.headersSent = true;
      return this;
    },
  };
}

beforeEach(() => {
  state.queries = [];
  state.updateLoanCalls = [];
  state.incrementCalls = 0;
  state.installmentCalls = 0;
  queryImpl = async () => ({ rows: [], rowCount: 0 });
  updateLoanImpl = async () => null;
});

test('receipt download rejects a non-owner before reading the blob', async () => {
  queryImpl = async () => ({ rows: [{ user_id: 22 }], rowCount: 1 });
  const res = responseMock();

  await downloadInstallmentReceipt(
    { params: { installmentId: '7' }, user: { id: 11, role: 'cliente' } },
    res,
  );

  assert.equal(res.statusCode, 403);
  assert.equal(state.queries.length, 1);
  assert.doesNotMatch(state.queries[0].sql, /receipt_file/i);
});

test('receipt download for the owner is read-only', async () => {
  const pdf = Buffer.from('%PDF-1.4\nmock');
  queryImpl = async () => {
    if (state.queries.length === 1) return { rows: [{ user_id: 11 }], rowCount: 1 };
    return {
      rows: [{ receipt_file: pdf, receipt_mime: 'application/pdf', receipt_original_name: 'receipt.pdf' }],
      rowCount: 1,
    };
  };
  const res = responseMock();

  await downloadInstallmentReceipt(
    { params: { installmentId: '7' }, user: { id: 11, role: 'cliente' } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, pdf);
  assert.equal(res.headers['cache-control'], 'private, no-store');
  assert.equal(state.queries.length, 2);
  assert.equal(state.queries.some(({ sql }) => /^\s*UPDATE\b/i.test(sql)), false);
});

test('receipt image conversion happens in memory without an UPDATE', async () => {
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    'base64',
  );
  queryImpl = async () => {
    if (state.queries.length === 1) return { rows: [{ user_id: 11 }], rowCount: 1 };
    return {
      rows: [{ receipt_file: png, receipt_mime: 'image/png', receipt_original_name: 'receipt.png' }],
      rowCount: 1,
    };
  };
  const res = responseMock();

  await downloadInstallmentReceipt(
    { params: { installmentId: '8' }, user: { id: 11, role: 'cliente' } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(Buffer.isBuffer(res.body), true);
  assert.equal(res.body.subarray(0, 5).toString('utf8'), '%PDF-');
  assert.equal(state.queries.some(({ sql }) => /^\s*UPDATE\b/i.test(sql)), false);
});

test('a normal user cannot directly set document approval bits', async () => {
  const res = responseMock();

  await updateUserDocumentStatus(
    { user: { id: 11, role: 'cliente' }, body: { document_status_code: 255 } },
    res,
  );

  assert.equal(res.statusCode, 403);
  assert.equal(state.queries.length, 0);
});

test('document status bitmask rejects values outside its 8-bit range', async () => {
  const res = responseMock();

  await updateUserDocumentStatus(
    { user: { id: 1, role: 'admin' }, body: { document_status_code: 256 } },
    res,
  );

  assert.equal(res.statusCode, 400);
  assert.equal(state.queries.length, 0);
});

test('loan status requires an admin before querying', async () => {
  const res = responseMock();

  await updateLoanRequestStatusController(
    { params: { id: '3' }, body: { status: 'aprobado' }, user: { id: 11, role: 'cliente' } },
    res,
  );

  assert.equal(res.statusCode, 403);
  assert.equal(state.queries.length, 0);
});

test('repeating aprobado is an idempotent no-op', async () => {
  const approved = { id: 3, user_id: 11, status: 'aprobado' };
  queryImpl = async () => ({ rows: [approved], rowCount: 1 });
  const res = responseMock();

  await updateLoanRequestStatusController(
    { params: { id: '3' }, body: { status: 'aprobado' }, user: { id: 1, role: 'admin' } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.unchanged, true);
  assert.equal(state.updateLoanCalls.length, 0);
  assert.equal(state.incrementCalls, 0);
  assert.equal(state.installmentCalls, 0);
});

test('the first pendiente to aprobado transition runs approval effects once', async () => {
  const pending = { id: 3, user_id: 11, status: 'pendiente', amount: 100, months: 2, interest: 5 };
  const approved = { ...pending, status: 'aprobado' };
  queryImpl = async () => ({ rows: [pending], rowCount: 1 });
  updateLoanImpl = async () => approved;
  const res = responseMock();

  await updateLoanRequestStatusController(
    { params: { id: '3' }, body: { status: 'APROBADO' }, user: { id: 1, role: 'admin' } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.deepEqual(state.updateLoanCalls[0], [3, 'aprobado', 'pendiente']);
  assert.equal(state.incrementCalls, 1);
  assert.equal(state.installmentCalls, 1);
});

test('a concurrent duplicate approval does not repeat approval effects', async () => {
  const pending = { id: 3, user_id: 11, status: 'pendiente' };
  const approved = { ...pending, status: 'aprobado' };
  queryImpl = async () => {
    if (state.queries.length === 1) return { rows: [pending], rowCount: 1 };
    return { rows: [approved], rowCount: 1 };
  };
  updateLoanImpl = async () => null;
  const res = responseMock();

  await updateLoanRequestStatusController(
    { params: { id: '3' }, body: { status: 'aprobado' }, user: { id: 1, role: 'admin' } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.unchanged, true);
  assert.equal(state.incrementCalls, 0);
  assert.equal(state.installmentCalls, 0);
});

test('approved loans cannot be moved back to rechazado', async () => {
  queryImpl = async () => ({ rows: [{ id: 3, user_id: 11, status: 'aprobado' }], rowCount: 1 });
  const res = responseMock();

  await updateLoanRequestStatusController(
    { params: { id: '3' }, body: { status: 'rechazado' }, user: { id: 1, role: 'admin' } },
    res,
  );

  assert.equal(res.statusCode, 409);
  assert.equal(state.updateLoanCalls.length, 0);
  assert.equal(state.incrementCalls, 0);
});

test('an approved loan can be settled without repeating approval effects', async () => {
  const approved = { id: 3, user_id: 11, status: 'aprobado' };
  const settled = { ...approved, status: 'liquidado' };
  queryImpl = async () => ({ rows: [approved], rowCount: 1 });
  updateLoanImpl = async () => settled;
  const res = responseMock();

  await updateLoanRequestStatusController(
    { params: { id: '3' }, body: { status: 'liquidado' }, user: { id: 1, role: 'admin' } },
    res,
  );

  assert.equal(res.statusCode, 200);
  assert.deepEqual(state.updateLoanCalls, [[3, 'liquidado', 'aprobado']]);
  assert.equal(state.incrementCalls, 0);
  assert.equal(state.installmentCalls, 0);
});
