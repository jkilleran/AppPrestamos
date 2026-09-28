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
  emailCalls: 0,
  markCalls: [],
  notificationCalls: [],
  pushCalls: [],
  order: [],
};

let queryImpl;
let markImpl;
let emailImpl;
let listAdminsImpl;

installMock('../db', {
  async query(sql, params) {
    return queryImpl(String(sql), params);
  },
});

installMock('../models/loan_installment.model', {
  getInstallmentsByLoan: async () => [],
  createInstallmentsForLoan: async () => ({ created: 0 }),
  async markInstallmentReported(args) {
    state.markCalls.push(args);
    state.order.push('persist');
    return markImpl(args);
  },
  updateInstallmentStatus: async () => null,
  getActiveLoansWithAggregates: async () => [],
  markOverdueInstallments: async () => ({ updated: 0 }),
  getLoanProgress: async () => ({}),
});

installMock('../models/loan_installment_log.model', {
  logInstallmentChange: async () => {},
});

installMock('../controllers/upload.controller', {
  async sendDocumentEmail(req, res) {
    state.emailCalls += 1;
    state.order.push('email');
    return emailImpl(req, res);
  },
});

installMock('../models/user.model', {
  async listAdmins() {
    return listAdminsImpl();
  },
});

installMock('../models/notification.model', {
  async createNotification(...args) {
    state.notificationCalls.push(args);
    state.order.push('notification');
  },
});

installMock('../services/push', {
  async sendPushToUser(args) {
    state.pushCalls.push(args);
    state.order.push('push');
  },
});

const {
  reportPaymentReceipt,
} = require('../controllers/loan_installment.controller');

function responseMock() {
  return {
    statusCode: 200,
    body: undefined,
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
  };
}

function validRequest(overrides = {}) {
  return {
    params: { installmentId: '7' },
    user: {
      id: 11,
      role: 'cliente',
      name: 'Cliente de prueba',
      email: 'cliente@example.test',
    },
    body: {},
    file: {
      originalname: 'comprobante.pdf',
      mimetype: 'application/pdf',
      size: 18,
      buffer: Buffer.from('%PDF-1.4\nreceipt'),
    },
    ...overrides,
  };
}

beforeEach(() => {
  state.emailCalls = 0;
  state.markCalls = [];
  state.notificationCalls = [];
  state.pushCalls = [];
  state.order = [];

  queryImpl = async () => ({
    rows: [{
      id: 7,
      user_id: 11,
      loan_request_id: 30,
      installment_number: 2,
      status: 'pendiente',
    }],
    rowCount: 1,
  });
  markImpl = async () => ({
    id: 7,
    loan_request_id: 30,
    installment_number: 2,
    status: 'reportado',
    receipt_mime: 'application/pdf',
  });
  emailImpl = async (_req, res) => res.json({ ok: true, message: 'Documento enviado' });
  listAdminsImpl = async () => [];
});

test('persists and responds before a rejecting email notifier completes', { timeout: 1000 }, async () => {
  let rejectEmail;
  emailImpl = async () => new Promise((_, reject) => {
    rejectEmail = reject;
  });
  const res = responseMock();

  await reportPaymentReceipt(validRequest(), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.installment.status, 'reportado');
  assert.equal(state.markCalls.length, 1);
  assert.equal(state.emailCalls, 1);
  assert.equal(state.order.indexOf('persist') < state.order.indexOf('email'), true);

  rejectEmail(new Error('SMTP disabled for test'));
  await new Promise((resolve) => setImmediate(resolve));
});

test('persists first and keeps successful admin and email notifications', async () => {
  listAdminsImpl = async () => [{ id: 99 }];
  const res = responseMock();

  await reportPaymentReceipt(validRequest(), res);
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.ok, true);
  assert.equal(state.markCalls.length, 1);
  assert.equal(state.emailCalls, 1);
  assert.equal(state.notificationCalls.length, 1);
  assert.equal(state.pushCalls.length, 1);
  assert.equal(state.order[0], 'persist');
});

test('rejects a missing receipt before persistence or notification', async () => {
  const res = responseMock();

  await reportPaymentReceipt(validRequest({ file: undefined }), res);

  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error, 'Archivo requerido');
  assert.equal(state.markCalls.length, 0);
  assert.equal(state.emailCalls, 0);
  assert.equal(state.notificationCalls.length, 0);
});

test('returns an error and skips notifications when receipt persistence fails', async () => {
  markImpl = async () => {
    throw new Error('database unavailable');
  };
  listAdminsImpl = async () => [{ id: 99 }];
  const res = responseMock();

  await reportPaymentReceipt(validRequest(), res);

  assert.equal(res.statusCode, 500);
  assert.equal(res.body.error, 'Error guardando recibo');
  assert.equal(state.markCalls.length, 1);
  assert.equal(state.emailCalls, 0);
  assert.equal(state.notificationCalls.length, 0);
  assert.equal(state.pushCalls.length, 0);
});
