'use strict';

process.env.JWT_SECRET = 'p0-http-smoke-test-secret-only';

const assert = require('node:assert/strict');
const { beforeEach, test } = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');
const request = require('supertest');

function installMock(requestPath, exports) {
  const filename = require.resolve(requestPath);
  require.cache[filename] = {
    id: filename,
    filename,
    loaded: true,
    exports,
  };
}

const state = {
  dbQueries: [],
  emailCalls: 0,
  markCalls: 0,
  notifierCalls: 0,
  uploadCalls: 0,
};

let emailImpl;
let notifierImpl;

installMock('../db', {
  async query(sql, params) {
    const statement = String(sql);
    state.dbQueries.push({ sql: statement, params });

    if (/FROM loan_installments i\s+JOIN loan_requests/i.test(statement)) {
      return {
        rows: [{
          id: 7,
          user_id: 11,
          loan_request_id: 30,
          installment_number: 2,
          status: 'pendiente',
        }],
        rowCount: 1,
      };
    }
    if (/SELECT document_status_code FROM users WHERE email/i.test(statement)) {
      return { rows: [{ document_status_code: 0 }], rowCount: 1 };
    }
    if (/^\s*UPDATE users/i.test(statement)) {
      return { rows: [], rowCount: 1 };
    }
    if (/SELECT id, document_status_notes FROM users WHERE email/i.test(statement)) {
      return { rows: [{ id: 42, document_status_notes: {} }], rowCount: 1 };
    }
    throw new Error(`Unexpected query in P0 HTTP smoke test: ${statement}`);
  },
});

installMock('../models/loan_installment.model', {
  getInstallmentsByLoan: async () => [],
  createInstallmentsForLoan: async () => ({ created: 0 }),
  async markInstallmentReported() {
    state.markCalls += 1;
    return {
      id: 7,
      loan_request_id: 30,
      installment_number: 2,
      status: 'reportado',
      receipt_mime: 'application/pdf',
    };
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
  uploadSingleSafe(req, _res, next) {
    state.uploadCalls += 1;
    req.file = {
      originalname: 'smoke-receipt.pdf',
      mimetype: 'application/pdf',
      size: 23,
      buffer: Buffer.from('%PDF-1.4\nsmoke-receipt'),
    };
    next();
  },
  async sendDocumentEmail(req, res) {
    state.emailCalls += 1;
    return emailImpl(req, res);
  },
});

installMock('../models/user.model', {
  findUserByEmail: async () => ({
    id: 42,
    name: 'HTTP Smoke User',
    email: 'smoke-user@example.test',
  }),
  findUserById: async (id) => ({ id }),
  findUserByCedula: async () => null,
  listAdmins: async () => [],
});

installMock('../models/notification.model', {
  createNotification: async () => null,
});

installMock('../services/push', {
  sendPushToUser: async () => null,
});

installMock('../services/notifier', {
  async notifyDocumentStatusCodeChange(args) {
    state.notifierCalls += 1;
    return notifierImpl(args);
  },
});

installMock('../utils/validation', {
  isValidCedula: () => true,
  normalizeCedula: (value) => value,
});

const loanInstallmentRoutes = require('../routes/loan_installment.routes');
const documentStatusRoutes = require('../routes/document_status.routes');

const app = express();
app.use(express.json());
app.use('/loan-installments', loanInstallmentRoutes);
app.use('/api/document-status', documentStatusRoutes);

function authToken({ id, role }) {
  return jwt.sign(
    { id, role, name: 'HTTP Smoke', email: 'smoke@example.test' },
    process.env.JWT_SECRET,
    { expiresIn: '1h' },
  );
}

beforeEach(() => {
  state.dbQueries = [];
  state.emailCalls = 0;
  state.markCalls = 0;
  state.notifierCalls = 0;
  state.uploadCalls = 0;
  emailImpl = async (_req, res) => res.json({ ok: true });
  notifierImpl = async () => undefined;
});

test('receipt report rejects an unauthenticated HTTP request before upload or persistence', async () => {
  const response = await request(app)
    .post('/loan-installments/installment/7/report')
    .expect(401);

  assert.equal(response.body.error, 'Token requerido');
  assert.equal(state.uploadCalls, 0);
  assert.equal(state.markCalls, 0);
  assert.equal(state.dbQueries.length, 0);
});

test('receipt report stays successful over HTTP when optional email rejects', async () => {
  emailImpl = async () => {
    throw new Error('SMTP intentionally disabled in HTTP smoke test');
  };

  const response = await request(app)
    .post('/loan-installments/installment/7/report')
    .set('Authorization', `Bearer ${authToken({ id: 11, role: 'cliente' })}`)
    .expect(200);

  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(response.body.ok, true);
  assert.equal(response.body.installment.status, 'reportado');
  assert.equal(state.markCalls, 1);
  assert.equal(state.emailCalls, 1);
});

test('document status route rejects a non-admin before touching the database', async () => {
  const response = await request(app)
    .put('/api/document-status/by-email')
    .set('Authorization', `Bearer ${authToken({ id: 11, role: 'cliente' })}`)
    .send({
      email: 'smoke-user@example.test',
      document_status_code: 64,
      doc: 'cedula',
      state: 'enviado',
    })
    .expect(403);

  assert.equal(response.body.error, 'No autorizado');
  assert.equal(state.dbQueries.length, 0);
  assert.equal(state.notifierCalls, 0);
});

test('document status update stays successful over HTTP when optional notifier rejects', async () => {
  const unhandled = [];
  const onUnhandledRejection = (reason) => unhandled.push(reason);
  process.on('unhandledRejection', onUnhandledRejection);
  notifierImpl = async () => {
    throw new Error('SMTP intentionally disabled in HTTP smoke test');
  };

  try {
    const response = await request(app)
      .put('/api/document-status/by-email')
      .set('Authorization', `Bearer ${authToken({ id: 1, role: 'admin' })}`)
      .send({
        email: 'smoke-user@example.test',
        document_status_code: 64,
        doc: 'cedula',
        state: 'enviado',
      })
      .expect(200);

    await new Promise((resolve) => setImmediate(resolve));

    assert.equal(response.body.success, true);
    assert.equal(state.notifierCalls, 1);
    assert.deepEqual(unhandled, []);
  } finally {
    process.off('unhandledRejection', onUnhandledRejection);
  }
});
