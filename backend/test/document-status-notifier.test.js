'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

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
  notifierCalls: 0,
  inAppCalls: 0,
  pushCalls: 0,
};

installMock('../db', {
  async query(sql) {
    const statement = String(sql);
    if (/SELECT document_status_code FROM users WHERE email/i.test(statement)) {
      return { rows: [{ document_status_code: 0 }], rowCount: 1 };
    }
    if (/^\s*UPDATE users/i.test(statement)) {
      return { rows: [], rowCount: 1 };
    }
    if (/SELECT id, document_status_notes FROM users WHERE email/i.test(statement)) {
      return { rows: [{ id: 42, document_status_notes: {} }], rowCount: 1 };
    }
    throw new Error('Unexpected database query in document notifier regression test');
  },
});

installMock('../models/user.model', {
  findUserByEmail: async () => ({
    id: 42,
    name: 'Test User',
    email: 'pii-sentinel@example.test',
  }),
  findUserById: async () => null,
  findUserByCedula: async () => null,
});

installMock('../utils/validation', {
  isValidCedula: () => true,
  normalizeCedula: (value) => value,
});

installMock('../services/notifier', {
  async notifyDocumentStatusCodeChange() {
    state.notifierCalls += 1;
    const error = new Error(
      'SMTP disabled; pii-sentinel@example.test; secret-sentinel-value',
    );
    error.code = 'SMTP_DISABLED_WITH_SECRET';
    throw error;
  },
});

installMock('../services/push', {
  async sendPushToUser() {
    state.pushCalls += 1;
  },
});

installMock('../models/notification.model', {
  async createNotification() {
    state.inAppCalls += 1;
  },
});

const {
  updateDocumentStatusByEmail,
} = require('../controllers/document_status.controller');

function responseMock() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('a rejected document email is contained and does not fail the status update', async () => {
  const unhandled = [];
  const warnings = [];
  const onUnhandledRejection = (reason) => unhandled.push(reason);
  const originalWarn = console.warn;

  process.on('unhandledRejection', onUnhandledRejection);
  console.warn = (...args) => warnings.push(args);

  try {
    const res = responseMock();

    await updateDocumentStatusByEmail(
      {
        body: {
          email: 'pii-sentinel@example.test',
          document_status_code: 64,
          doc: 'cedula',
          state: 'enviado',
        },
      },
      res,
    );

    // Let the deliberately detached best-effort email settle.
    await new Promise((resolve) => setImmediate(resolve));

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.success, true);
    assert.equal(state.notifierCalls, 1);
    assert.equal(state.inAppCalls, 1);
    assert.equal(state.pushCalls, 1);
    assert.deepEqual(unhandled, []);

    const warningText = JSON.stringify(warnings);
    assert.match(warningText, /optional_email/);
    assert.doesNotMatch(warningText, /pii-sentinel/i);
    assert.doesNotMatch(warningText, /secret-sentinel/i);
    assert.doesNotMatch(warningText, /SMTP_DISABLED_WITH_SECRET/i);
  } finally {
    console.warn = originalWarn;
    process.off('unhandledRejection', onUnhandledRejection);
  }
});
