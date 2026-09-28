'use strict';

const assert = require('node:assert/strict');
const { test, describe } = require('node:test');

const { serializeLoanPolicySnapshot } = require('../services/loanPolicySerialization');

function monthlyFixture(overrides = {}) {
  return Object.assign({
    schemaVersion: 1,
    policyId: 'fixture-monthly',
    policyVersion: 1,
    currency: 'DOP',
    amount: { minMinor: 1000000, maxMinor: 2000000 },
    interest: { rateBps: 1800, period: 'monthly', method: 'equal_principal_declining_balance' },
    repayment: { installmentCount: 2, intervalDays: 30 }
  }, overrides);
}

function annualFixture(overrides = {}) {
  return Object.assign({
    schemaVersion: 1,
    policyId: 'fixture-annual',
    policyVersion: 1,
    currency: 'DOP',
    amount: { minMinor: 500000, maxMinor: 1500000 },
    interest: { rateBps: 2400, period: 'annual', method: 'equal_principal_declining_balance' },
    repayment: { installmentCount: 12, intervalDays: 30 }
  }, overrides);
}

describe('serializeLoanPolicySnapshot', () => {
  test('serializes valid monthly policy to canonical JSON', () => {
    const input = monthlyFixture();
    const json = serializeLoanPolicySnapshot(input);
    const expected = '{"schemaVersion":1,"policyId":"fixture-monthly","policyVersion":1,"currency":"DOP","amount":{"minMinor":1000000,"maxMinor":2000000},"interest":{"rateBps":1800,"period":"monthly","method":"equal_principal_declining_balance"},"repayment":{"installmentCount":2,"intervalDays":30}}';
    assert.equal(json, expected);
  });

  test('serializes valid annual policy to canonical JSON', () => {
    const input = annualFixture();
    const json = serializeLoanPolicySnapshot(input);
    const expected = '{"schemaVersion":1,"policyId":"fixture-annual","policyVersion":1,"currency":"DOP","amount":{"minMinor":500000,"maxMinor":1500000},"interest":{"rateBps":2400,"period":"annual","method":"equal_principal_declining_balance"},"repayment":{"installmentCount":12,"intervalDays":30}}';
    assert.equal(json, expected);
  });

  test('serializes policy with reordered input keys to same canonical output', () => {
    // Input with keys in different order
    const input = {
      repayment: { installmentCount: 2, intervalDays: 30 },
      interest: { rateBps: 1800, period: 'monthly', method: 'equal_principal_declining_balance' },
      amount: { minMinor: 1000000, maxMinor: 2000000 },
      currency: 'DOP',
      policyVersion: 1,
      policyId: 'fixture-monthly',
      schemaVersion: 1
    };
    const json = serializeLoanPolicySnapshot(input);
    const expected = '{"schemaVersion":1,"policyId":"fixture-monthly","policyVersion":1,"currency":"DOP","amount":{"minMinor":1000000,"maxMinor":2000000},"interest":{"rateBps":1800,"period":"monthly","method":"equal_principal_declining_balance"},"repayment":{"installmentCount":2,"intervalDays":30}}';
    assert.equal(json, expected);
  });

  test('serializes -0 as 0 in JSON output', () => {
    const input = monthlyFixture();
    input.interest.rateBps = -0; // -0 is valid for nonnegative
    const json = serializeLoanPolicySnapshot(input);
    // JSON.stringify converts -0 to 0
    assert.ok(!json.includes('-0'), 'JSON should not contain -0');
    assert.ok(json.includes('"rateBps":0'), 'rateBps should be 0 in JSON');
  });

  test('throws TypeError for invalid input', () => {
    const invalid = monthlyFixture();
    invalid.schemaVersion = 2;
    assert.throws(
      () => serializeLoanPolicySnapshot(invalid),
      (err) => {
        assert.ok(err instanceof TypeError);
        assert.equal(err.message, 'Invalid loan policy');
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        assert.ok(Array.isArray(err.errors));
        return true;
      },
      'should throw for invalid input'
    );
  });

  test('throws TypeError for null input', () => {
    assert.throws(
      () => serializeLoanPolicySnapshot(null),
      (err) => {
        assert.ok(err instanceof TypeError);
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        return true;
      },
      'should throw for null input'
    );
  });

  test('throws TypeError for empty object', () => {
    assert.throws(
      () => serializeLoanPolicySnapshot({}),
      (err) => {
        assert.ok(err instanceof TypeError);
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        return true;
      },
      'should throw for empty object'
    );
  });

  test('error object contains validation errors', () => {
    const invalid = monthlyFixture();
    invalid.schemaVersion = 2;
    try {
      serializeLoanPolicySnapshot(invalid);
      assert.fail('should have thrown');
    } catch (err) {
      assert.deepEqual(err.errors, [{ path: 'schemaVersion', code: 'INVALID_VALUE' }]);
    }
  });

  test('serializes valid input with different policyVersion', () => {
    const input = monthlyFixture({ policyVersion: 5 });
    const json = serializeLoanPolicySnapshot(input);
    assert.ok(json.includes('"policyVersion":5'));
  });

  test('serializes valid input with zero interest rate', () => {
    const input = monthlyFixture({ interest: { rateBps: 0, period: 'monthly', method: 'equal_principal_declining_balance' } });
    const json = serializeLoanPolicySnapshot(input);
    assert.ok(json.includes('"rateBps":0'));
  });

  test('serializes valid input with equal amount bounds', () => {
    const input = monthlyFixture({ amount: { minMinor: 10000, maxMinor: 10000 } });
    const json = serializeLoanPolicySnapshot(input);
    assert.ok(json.includes('"minMinor":10000'));
    assert.ok(json.includes('"maxMinor":10000'));
  });

  test('serializes valid input with different installment count', () => {
    const input = monthlyFixture({ repayment: { installmentCount: 5, intervalDays: 14 } });
    const json = serializeLoanPolicySnapshot(input);
    assert.ok(json.includes('"installmentCount":5'));
    assert.ok(json.includes('"intervalDays":14'));
  });

  test('output is valid JSON that parses correctly', () => {
    const input = monthlyFixture();
    const json = serializeLoanPolicySnapshot(input);
    const parsed = JSON.parse(json);
    assert.equal(parsed.schemaVersion, 1);
    assert.equal(parsed.policyId, 'fixture-monthly');
    assert.equal(parsed.policyVersion, 1);
    assert.equal(parsed.currency, 'DOP');
    assert.equal(parsed.amount.minMinor, 1000000);
    assert.equal(parsed.amount.maxMinor, 2000000);
    assert.equal(parsed.interest.rateBps, 1800);
    assert.equal(parsed.interest.period, 'monthly');
    assert.equal(parsed.interest.method, 'equal_principal_declining_balance');
    assert.equal(parsed.repayment.installmentCount, 2);
    assert.equal(parsed.repayment.intervalDays, 30);
  });

  test('deterministic output - multiple calls produce identical JSON', () => {
    const input = monthlyFixture();
    const json1 = serializeLoanPolicySnapshot(input);
    const json2 = serializeLoanPolicySnapshot(input);
    assert.equal(json1, json2);
  });

  test('does not mutate input', () => {
    const input = monthlyFixture();
    const originalPolicyId = input.policyId;
    const originalRateBps = input.interest.rateBps;
    serializeLoanPolicySnapshot(input);
    assert.equal(input.policyId, originalPolicyId);
    assert.equal(input.interest.rateBps, originalRateBps);
  });

  test('frozen input accepted', () => {
    const input = Object.freeze(monthlyFixture());
    Object.freeze(input.amount);
    Object.freeze(input.interest);
    Object.freeze(input.repayment);
    const json = serializeLoanPolicySnapshot(input);
    assert.ok(json.includes('"policyId":"fixture-monthly"'));
  });

  test('null-prototype input produces valid JSON', () => {
    const input = Object.create(null);
    Object.assign(input, monthlyFixture());
    const json = serializeLoanPolicySnapshot(input);
    assert.ok(json.startsWith('{'));
    assert.ok(json.endsWith('}'));
  });
});

// ============================================================================
// Test Suite - R1 Non-Finite Number Classification (Serializer)
// ============================================================================

describe('R1 Non-Finite Number Classification - serializeLoanPolicySnapshot', () => {
  const numericFields = [
    { field: 'schemaVersion', path: 'schemaVersion' },
    { field: 'policyVersion', path: 'policyVersion' },
    { field: 'amount.minMinor', path: 'amount.minMinor' },
    { field: 'amount.maxMinor', path: 'amount.maxMinor' },
    { field: 'interest.rateBps', path: 'interest.rateBps' },
    { field: 'repayment.installmentCount', path: 'repayment.installmentCount' },
    { field: 'repayment.intervalDays', path: 'repayment.intervalDays' }
  ];

  const nonFiniteValues = [
    { name: 'NaN', value: NaN },
    { name: 'Infinity', value: Infinity },
    { name: '-Infinity', value: -Infinity }
  ];

  numericFields.forEach(({ field, path }) => {
    nonFiniteValues.forEach(({ name, value }) => {
      test(`${field} = ${name} → serializer throws INVALID_VALUE`, () => {
        const input = monthlyFixture();
        const parts = field.split('.');
        let current = input;
        for (let i = 0; i < parts.length - 1; i++) {
          current = current[parts[i]];
        }
        current[parts[parts.length - 1]] = value;
        assert.throws(
          () => serializeLoanPolicySnapshot(input),
          (err) => {
            assert.ok(err instanceof TypeError);
            assert.equal(err.message, 'Invalid loan policy');
            assert.equal(err.code, 'INVALID_LOAN_POLICY');
            assert.deepEqual(err.errors, [{ path, code: 'INVALID_VALUE' }]);
            return true;
          },
          `serializer throws for ${field}=${name}`
        );
      });
    });
  });
});

// ============================================================================
// Test Suite - R2 Serializer Mandatory Coverage
// ============================================================================

describe('R2 Serializer Reordered Key Order - serializeLoanPolicySnapshot', () => {
  test('reordered root and nested keys produce same golden monthly string', () => {
    const input = {
      repayment: { intervalDays: 30, installmentCount: 2 },
      interest: { method: 'equal_principal_declining_balance', period: 'monthly', rateBps: 1800 },
      currency: 'DOP',
      amount: { maxMinor: 2000000, minMinor: 1000000 },
      policyVersion: 1,
      policyId: 'fixture-monthly',
      schemaVersion: 1
    };
    const json = serializeLoanPolicySnapshot(input);
    const expected = '{"schemaVersion":1,"policyId":"fixture-monthly","policyVersion":1,"currency":"DOP","amount":{"minMinor":1000000,"maxMinor":2000000},"interest":{"rateBps":1800,"period":"monthly","method":"equal_principal_declining_balance"},"repayment":{"installmentCount":2,"intervalDays":30}}';
    assert.equal(json, expected);
  });

  test('reordered root and nested keys produce same golden annual string', () => {
    const input = {
      repayment: { intervalDays: 30, installmentCount: 12 },
      interest: { method: 'equal_principal_declining_balance', period: 'annual', rateBps: 2400 },
      currency: 'DOP',
      amount: { maxMinor: 1500000, minMinor: 500000 },
      policyVersion: 1,
      policyId: 'fixture-annual',
      schemaVersion: 1
    };
    const json = serializeLoanPolicySnapshot(input);
    const expected = '{"schemaVersion":1,"policyId":"fixture-annual","policyVersion":1,"currency":"DOP","amount":{"minMinor":500000,"maxMinor":1500000},"interest":{"rateBps":2400,"period":"annual","method":"equal_principal_declining_balance"},"repayment":{"installmentCount":12,"intervalDays":30}}';
    assert.equal(json, expected);
  });
});

describe('R2 Serializer -0 and Nested Null Prototype', () => {
  test('rateBps: -0 becomes positive 0 in parsed JSON while snapshot remains -0', () => {
    const input = monthlyFixture();
    input.interest.rateBps = -0;
    const json = serializeLoanPolicySnapshot(input);
    // JSON output should have 0, not -0
    assert.ok(!json.includes('-0'), 'JSON should not contain -0');
    assert.ok(json.includes('"rateBps":0'), 'rateBps should be 0 in JSON');

    // But the original snapshot should preserve -0 (Object.is)
    const { createLoanPolicySnapshot } = require('../services/loanPolicy');
    const snapshot = createLoanPolicySnapshot(input);
    assert.ok(Object.is(snapshot.interest.rateBps, -0), 'Snapshot should preserve -0');
  });

  test('positive amount fields reject zero/-0 in serializer too', () => {
    const input = monthlyFixture();
    input.amount.minMinor = -0;
    assert.throws(
      () => serializeLoanPolicySnapshot(input),
      (err) => {
        assert.ok(err instanceof TypeError);
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        return true;
      },
      'serializer rejects -0 for amount.minMinor'
    );

    input.amount.minMinor = 1000000;
    input.amount.maxMinor = -0;
    assert.throws(
      () => serializeLoanPolicySnapshot(input),
      (err) => {
        assert.ok(err instanceof TypeError);
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        return true;
      },
      'serializer rejects -0 for amount.maxMinor'
    );
  });

  test('nested null prototype objects accepted', () => {
    const input = monthlyFixture();
    input.amount = Object.create(null);
    Object.assign(input.amount, { minMinor: 1000000, maxMinor: 2000000 });
    input.interest = Object.create(null);
    Object.assign(input.interest, { rateBps: 1800, period: 'monthly', method: 'equal_principal_declining_balance' });
    input.repayment = Object.create(null);
    Object.assign(input.repayment, { installmentCount: 2, intervalDays: 30 });
    const json = serializeLoanPolicySnapshot(input);
    assert.equal(json, '{"schemaVersion":1,"policyId":"fixture-monthly","policyVersion":1,"currency":"DOP","amount":{"minMinor":1000000,"maxMinor":2000000},"interest":{"rateBps":1800,"period":"monthly","method":"equal_principal_declining_balance"},"repayment":{"installmentCount":2,"intervalDays":30}}');
  });
});

describe('R2 Serializer Literal Invalid Input Errors', () => {
  test('literal error array for schemaVersion invalid', () => {
    const input = monthlyFixture({ schemaVersion: 2 });
    try {
      serializeLoanPolicySnapshot(input);
      assert.fail('should throw');
    } catch (err) {
      assert.deepEqual(err.errors, [{ path: 'schemaVersion', code: 'INVALID_VALUE' }]);
    }
  });

  test('literal error array for multiple fields', () => {
    const input = monthlyFixture({
      schemaVersion: 2,
      policyId: '',
      interest: { rateBps: -1, period: 'weekly', method: 'equal_principal_declining_balance' }
    });
    try {
      serializeLoanPolicySnapshot(input);
      assert.fail('should throw');
    } catch (err) {
      assert.deepEqual(err.errors, [
        { path: 'interest.period', code: 'INVALID_VALUE' },
        { path: 'interest.rateBps', code: 'INVALID_VALUE' },
        { path: 'policyId', code: 'INVALID_VALUE' },
        { path: 'schemaVersion', code: 'INVALID_VALUE' }
      ]);
    }
  });
});

describe('R2 Serializer Source Inspection (complementary, not import-isolation proof)', () => {
  test('loanPolicySerialization source has no forbidden imports', () => {
    const fs = require('fs');
    const { resolve } = require('path');
    const serializerPath = resolve(__dirname, '../services/loanPolicySerialization.js');
    const source = fs.readFileSync(serializerPath, 'utf8');
    // Should only import loanPolicy
    const allowed = ['../services/loanPolicy'];
    const forbidden = ['../db', '../models', '../controllers', '../routes', '../services/loanPolicySerialization', 'dotenv', 'express', 'pg', 'jsonwebtoken', 'bcryptjs', 'cors', 'multer', 'nodemailer', 'pdfkit'];
    for (const f of forbidden) {
      if (source.includes("require('" + f) || source.includes('require("' + f)) {
        assert.fail('FORBIDDEN import: ' + f);
      }
    }
    assert.ok(true);
  });

  test('serializer repeat calls produce identical JSON', () => {
    const input = monthlyFixture();
    const json1 = serializeLoanPolicySnapshot(input);
    const json2 = serializeLoanPolicySnapshot(input);
    const json3 = serializeLoanPolicySnapshot(input);
    assert.equal(json1, json2);
    assert.equal(json2, json3);
  });
});

// ============================================================================
// Test Suite - F1-F4 Fresh-Process Import Isolation Proof - loanPolicySerialization
// ============================================================================

describe('F1-F4 Fresh-Process Import Isolation Proof - loanPolicySerialization', () => {
  const { execFileSync } = require('child_process');
  const { resolve } = require('path');
  const serializerPath = resolve(__dirname, '../services/loanPolicySerialization');
  const loanPolicyPath = resolve(__dirname, '../services/loanPolicy');

  test('F1-F2: imports cleanly with exact sorted exports', () => {
    const script = `
      const mod = require('${serializerPath}');
      const exports = Object.keys(mod).sort();
      console.log('EXPORTS_JSON:' + JSON.stringify(exports));
      console.log('TYPE_SERIALIZE:' + typeof mod.serializeLoanPolicySnapshot);
    `;
    const output = execFileSync(process.execPath, ['-e', script], {
      timeout: 5000,
      env: { ...process.env, NODE_OPTIONS: '' },
      cwd: __dirname
    }).toString().trim();

    const exportsLine = output.split('\n').find(l => l.startsWith('EXPORTS_JSON:'));
    const exports = JSON.parse(exportsLine.replace('EXPORTS_JSON:', ''));
    assert.deepEqual(exports, ['serializeLoanPolicySnapshot']);

    const typeLine = output.split('\n').find(l => l.startsWith('TYPE_SERIALIZE:'));
    assert.equal(typeLine.replace('TYPE_SERIALIZE:', ''), 'function');
  });

  test('F3: child loads no application modules beyond allowed (loanPolicy + serializer)', () => {
    const script = `
      const fs = require('fs');
      const mod = require('${serializerPath}');
      const allowed = new Set([
        require.resolve('${serializerPath}'),
        require.resolve('${loanPolicyPath}'),
        require.resolve('fs'),
        require.resolve('path'),
        require.resolve('child_process'),
        require.resolve('assert'),
        require.resolve('util')
      ]);
      // Check all loaded modules
      const loadedPaths = Object.keys(require.cache).filter(p => !p.includes('node_modules'));
      const forbidden = loadedPaths.filter(p => !allowed.has(p) && !p.endsWith('.node'));
      if (forbidden.length > 0) {
        console.error('FORBIDDEN:', JSON.stringify(forbidden));
        process.exit(1);
      }
      console.log('OK');
    `;
    const output = execFileSync(process.execPath, ['-e', script], {
      timeout: 5000,
      env: { ...process.env, NODE_OPTIONS: '' },
      cwd: __dirname
    }).toString().trim();
    assert.equal(output, 'OK');
  });
});

// ============================================================================
// E2: MAX_SAFE_INTEGER fixture for all numeric fields (schemaVersion stays 1)
// ============================================================================

describe('E2 MAX_SAFE_INTEGER Fixture - serializeLoanPolicySnapshot', () => {
  test('MAX_SAFE_INTEGER for policyVersion, equal bounds, rateBps, installmentCount, intervalDays', () => {
    const maxSafe = Number.MAX_SAFE_INTEGER;
    const input = {
      schemaVersion: 1,
      policyId: 'max-safe-fixture',
      policyVersion: maxSafe,
      currency: 'DOP',
      amount: { minMinor: maxSafe, maxMinor: maxSafe },
      interest: { rateBps: maxSafe, period: 'monthly', method: 'equal_principal_declining_balance' },
      repayment: { installmentCount: maxSafe, intervalDays: maxSafe }
    };
    const json = serializeLoanPolicySnapshot(input);
    const parsed = JSON.parse(json);
    assert.equal(parsed.schemaVersion, 1);
    assert.equal(parsed.policyId, 'max-safe-fixture');
    assert.equal(parsed.policyVersion, maxSafe);
    assert.equal(parsed.currency, 'DOP');
    assert.equal(parsed.amount.minMinor, maxSafe);
    assert.equal(parsed.amount.maxMinor, maxSafe);
    assert.equal(parsed.interest.rateBps, maxSafe);
    assert.equal(parsed.interest.period, 'monthly');
    assert.equal(parsed.interest.method, 'equal_principal_declining_balance');
    assert.equal(parsed.repayment.installmentCount, maxSafe);
    assert.equal(parsed.repayment.intervalDays, maxSafe);
  });

  test('deterministic repetition with MAX_SAFE_INTEGER fixture', () => {
    const maxSafe = Number.MAX_SAFE_INTEGER;
    const input = {
      schemaVersion: 1,
      policyId: 'max-safe-fixture',
      policyVersion: maxSafe,
      currency: 'DOP',
      amount: { minMinor: maxSafe, maxMinor: maxSafe },
      interest: { rateBps: maxSafe, period: 'monthly', method: 'equal_principal_declining_balance' },
      repayment: { installmentCount: maxSafe, intervalDays: maxSafe }
    };
    const json1 = serializeLoanPolicySnapshot(input);
    const json2 = serializeLoanPolicySnapshot(input);
    const json3 = serializeLoanPolicySnapshot(input);
    assert.equal(json1, json2);
    assert.equal(json2, json3);
  });
});

// ============================================================================
// E3: Full error contract and literal arrays for invalid inputs
// ============================================================================

describe('E3 Full Error Contract - serializeLoanPolicySnapshot', () => {
  test('undefined policyVersion → REQUIRED literal array', () => {
    const input = monthlyFixture();
    delete input.policyVersion;
    try {
      serializeLoanPolicySnapshot(input);
      assert.fail('should throw');
    } catch (err) {
      assert.ok(err instanceof TypeError);
      assert.equal(err.message, 'Invalid loan policy');
      assert.equal(err.code, 'INVALID_LOAN_POLICY');
      assert.deepEqual(err.errors, [{ path: 'policyVersion', code: 'REQUIRED' }]);
    }
  });

  test('string rateBps → INVALID_TYPE literal array', () => {
    const input = monthlyFixture();
    input.interest.rateBps = '1800';
    try {
      serializeLoanPolicySnapshot(input);
      assert.fail('should throw');
    } catch (err) {
      assert.ok(err instanceof TypeError);
      assert.equal(err.message, 'Invalid loan policy');
      assert.equal(err.code, 'INVALID_LOAN_POLICY');
      assert.deepEqual(err.errors, [{ path: 'interest.rateBps', code: 'INVALID_TYPE' }]);
    }
  });

  test('collision: input["amount.extra"]=1 and input.amount.extra=2 → single UNKNOWN_FIELD', () => {
    const input = monthlyFixture();
    input['amount.extra'] = 1;
    input.amount.extra = 2;
    try {
      serializeLoanPolicySnapshot(input);
      assert.fail('should throw');
    } catch (err) {
      assert.ok(err instanceof TypeError);
      assert.equal(err.message, 'Invalid loan policy');
      assert.equal(err.code, 'INVALID_LOAN_POLICY');
      assert.deepEqual(err.errors, [{ path: 'amount.extra', code: 'UNKNOWN_FIELD' }]);
    }
  });

  test('collision: input["interest.rateBps"]=1 and interest.rateBps="1800" → INVALID_TYPE + UNKNOWN_FIELD', () => {
    const input = monthlyFixture();
    input.interest.rateBps = '1800';  // string → INVALID_TYPE
    input['interest.rateBps'] = 1;    // number on root → UNKNOWN_FIELD
    try {
      serializeLoanPolicySnapshot(input);
      assert.fail('should throw');
    } catch (err) {
      assert.ok(err instanceof TypeError);
      assert.equal(err.message, 'Invalid loan policy');
      assert.equal(err.code, 'INVALID_LOAN_POLICY');
      const paths = err.errors.map(e => e.path).sort();
      const codes = err.errors.map(e => e.code).sort();
      assert.deepEqual(paths, ['interest.rateBps', 'interest.rateBps']);
      assert.deepEqual(codes, ['INVALID_TYPE', 'UNKNOWN_FIELD']);
    }
  });

  test('invalid input never returns JSON (always throws)', () => {
    const invalidCases = [
      monthlyFixture({ schemaVersion: 2 }),
      monthlyFixture({ policyVersion: 'not-a-number' }),
      monthlyFixture({ amount: { minMinor: -1, maxMinor: 100 } }),
      monthlyFixture({ interest: { rateBps: -1, period: 'monthly', method: 'equal_principal_declining_balance' } }),
    ];
    invalidCases.forEach((input, i) => {
      let threw = false;
      try {
        const result = serializeLoanPolicySnapshot(input);
        assert.fail(`Case ${i} should have thrown but returned: ${result}`);
      } catch (err) {
        threw = true;
        assert.ok(err instanceof TypeError);
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
      }
      assert.ok(threw, `Case ${i} did not throw`);
    });
  });
});

// ============================================================================
// E4: Input preservation (refs, values, frozen state) for nested null-prototype and frozen inputs
// ============================================================================

describe('E4 Input Preservation - serializeLoanPolicySnapshot', () => {
  test('nested null-prototype input: refs, values, frozen state unchanged', () => {
    const input = monthlyFixture();
    input.amount = Object.create(null);
    Object.assign(input.amount, { minMinor: 1000000, maxMinor: 2000000 });
    input.interest = Object.create(null);
    Object.assign(input.interest, { rateBps: 1800, period: 'monthly', method: 'equal_principal_declining_balance' });
    input.repayment = Object.create(null);
    Object.assign(input.repayment, { installmentCount: 2, intervalDays: 30 });

    const originalRefs = {
      root: input,
      amount: input.amount,
      interest: input.interest,
      repayment: input.repayment
    };
    const originalFrozen = {
      root: Object.isFrozen(input),
      amount: Object.isFrozen(input.amount),
      interest: Object.isFrozen(input.interest),
      repayment: Object.isFrozen(input.repayment)
    };
    // Use a plain object for value comparison since JSON.stringify loses null prototype
    const originalValues = {
      schemaVersion: 1,
      policyId: 'fixture-monthly',
      policyVersion: 1,
      currency: 'DOP',
      amount: { minMinor: 1000000, maxMinor: 2000000 },
      interest: { rateBps: 1800, period: 'monthly', method: 'equal_principal_declining_balance' },
      repayment: { installmentCount: 2, intervalDays: 30 }
    };

    const json = serializeLoanPolicySnapshot(input);

    // References unchanged
    assert.strictEqual(input, originalRefs.root);
    assert.strictEqual(input.amount, originalRefs.amount);
    assert.strictEqual(input.interest, originalRefs.interest);
    assert.strictEqual(input.repayment, originalRefs.repayment);

    // Frozen state unchanged
    assert.equal(Object.isFrozen(input), originalFrozen.root);
    assert.equal(Object.isFrozen(input.amount), originalFrozen.amount);
    assert.equal(Object.isFrozen(input.interest), originalFrozen.interest);
    assert.equal(Object.isFrozen(input.repayment), originalFrozen.repayment);

    // Values unchanged (deep equal, ignoring prototype)
    // Use a custom comparison that ignores prototype
    assert.deepStrictEqual({...input, amount: {...input.amount}, interest: {...input.interest}, repayment: {...input.repayment}}, originalValues);

    // JSON is valid
    const parsed = JSON.parse(json);
    assert.equal(parsed.schemaVersion, 1);
    assert.equal(parsed.policyId, 'fixture-monthly');
  });

  test('frozen input: refs, values, frozen state unchanged', () => {
    const input = Object.freeze(monthlyFixture());
    Object.freeze(input.amount);
    Object.freeze(input.interest);
    Object.freeze(input.repayment);

    const originalRefs = {
      root: input,
      amount: input.amount,
      interest: input.interest,
      repayment: input.repayment
    };
    const originalFrozen = {
      root: Object.isFrozen(input),
      amount: Object.isFrozen(input.amount),
      interest: Object.isFrozen(input.interest),
      repayment: Object.isFrozen(input.repayment)
    };
    const originalValues = JSON.parse(JSON.stringify(input));

    const json = serializeLoanPolicySnapshot(input);

    // References unchanged
    assert.strictEqual(input, originalRefs.root);
    assert.strictEqual(input.amount, originalRefs.amount);
    assert.strictEqual(input.interest, originalRefs.interest);
    assert.strictEqual(input.repayment, originalRefs.repayment);

    // Frozen state unchanged
    assert.equal(Object.isFrozen(input), originalFrozen.root);
    assert.equal(Object.isFrozen(input.amount), originalFrozen.amount);
    assert.equal(Object.isFrozen(input.interest), originalFrozen.interest);
    assert.equal(Object.isFrozen(input.repayment), originalFrozen.repayment);

    // Values unchanged
    assert.deepStrictEqual(input, originalValues);

    // JSON is valid
    const parsed = JSON.parse(json);
    assert.equal(parsed.schemaVersion, 1);
    assert.equal(parsed.policyId, 'fixture-monthly');
  });

  test('mutating caller after serialization does not alter prior JSON string', () => {
    const input = monthlyFixture();
    const json1 = serializeLoanPolicySnapshot(input);

    // Mutate the caller's input
    input.policyId = 'changed';
    input.amount.minMinor = 999999;
    input.interest.rateBps = 999;
    input.repayment.installmentCount = 999;

    const json2 = serializeLoanPolicySnapshot(input);

    // First JSON should be unchanged
    assert.equal(json1, '{"schemaVersion":1,"policyId":"fixture-monthly","policyVersion":1,"currency":"DOP","amount":{"minMinor":1000000,"maxMinor":2000000},"interest":{"rateBps":1800,"period":"monthly","method":"equal_principal_declining_balance"},"repayment":{"installmentCount":2,"intervalDays":30}}');

    // Second JSON reflects new values
    const parsed2 = JSON.parse(json2);
    assert.equal(parsed2.policyId, 'changed');
    assert.equal(parsed2.amount.minMinor, 999999);
    assert.equal(parsed2.interest.rateBps, 999);
    assert.equal(parsed2.repayment.installmentCount, 999);
  });
});

// ============================================================================
// E5: rateBps -0 preservation and positive amount field zero/-0 rejection
// ============================================================================

describe('E5 rateBps -0 and Positive Amount Rejection - serializeLoanPolicySnapshot', () => {
  test('caller preserves -0 via Object.is for rateBps', () => {
    const input = monthlyFixture();
    input.interest.rateBps = -0;
    assert.ok(Object.is(input.interest.rateBps, -0), 'caller should have -0');
    assert.ok(!Object.is(input.interest.rateBps, 0), 'caller -0 should be distinct from +0');

    const json = serializeLoanPolicySnapshot(input);
    const parsed = JSON.parse(json);
    assert.equal(parsed.interest.rateBps, 0, 'parsed JSON should have +0');

    // Snapshot also preserves -0
    const { createLoanPolicySnapshot } = require('../services/loanPolicy');
    const snapshot = createLoanPolicySnapshot(input);
    assert.ok(Object.is(snapshot.interest.rateBps, -0), 'snapshot should preserve -0');
    assert.ok(!Object.is(snapshot.interest.rateBps, 0), 'snapshot -0 distinct from +0');
  });

  test('positive amount fields reject zero with literal INVALID_VALUE', () => {
    const testCases = [
      { field: 'amount.minMinor', makeInput: (v) => monthlyFixture({ amount: { minMinor: v, maxMinor: 100 } }) },
      { field: 'amount.maxMinor', makeInput: (v) => monthlyFixture({ amount: { minMinor: 100, maxMinor: v } }) },
    ];

    testCases.forEach(({ field, makeInput }) => {
      const input = makeInput(0);
      try {
        serializeLoanPolicySnapshot(input);
        assert.fail(`${field}=0 should throw`);
      } catch (err) {
        assert.ok(err instanceof TypeError);
        assert.equal(err.message, 'Invalid loan policy');
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        assert.deepEqual(err.errors, [{ path: field, code: 'INVALID_VALUE' }]);
      }
    });
  });

  test('positive amount fields reject -0 with literal INVALID_VALUE', () => {
    const testCases = [
      { field: 'amount.minMinor', makeInput: (v) => monthlyFixture({ amount: { minMinor: v, maxMinor: 100 } }) },
      { field: 'amount.maxMinor', makeInput: (v) => monthlyFixture({ amount: { minMinor: 100, maxMinor: v } }) },
    ];

    testCases.forEach(({ field, makeInput }) => {
      const input = makeInput(-0);
      try {
        serializeLoanPolicySnapshot(input);
        assert.fail(`${field}=-0 should throw`);
      } catch (err) {
        assert.ok(err instanceof TypeError);
        assert.equal(err.message, 'Invalid loan policy');
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        assert.deepEqual(err.errors, [{ path: field, code: 'INVALID_VALUE' }]);
      }
    });
  });

  test('repayment positive fields reject zero with literal INVALID_VALUE', () => {
    const testCases = [
      { field: 'repayment.installmentCount', makeInput: (v) => monthlyFixture({ repayment: { installmentCount: v, intervalDays: 30 } }) },
      { field: 'repayment.intervalDays', makeInput: (v) => monthlyFixture({ repayment: { installmentCount: 2, intervalDays: v } }) },
    ];

    testCases.forEach(({ field, makeInput }) => {
      const input = makeInput(0);
      try {
        serializeLoanPolicySnapshot(input);
        assert.fail(`${field}=0 should throw`);
      } catch (err) {
        assert.ok(err instanceof TypeError);
        assert.equal(err.message, 'Invalid loan policy');
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        assert.deepEqual(err.errors, [{ path: field, code: 'INVALID_VALUE' }]);
      }
    });
  });

  test('repayment positive fields reject -0 with literal INVALID_VALUE', () => {
    const testCases = [
      { field: 'repayment.installmentCount', makeInput: (v) => monthlyFixture({ repayment: { installmentCount: v, intervalDays: 30 } }) },
      { field: 'repayment.intervalDays', makeInput: (v) => monthlyFixture({ repayment: { installmentCount: 2, intervalDays: v } }) },
    ];

    testCases.forEach(({ field, makeInput }) => {
      const input = makeInput(-0);
      try {
        serializeLoanPolicySnapshot(input);
        assert.fail(`${field}=-0 should throw`);
      } catch (err) {
        assert.ok(err instanceof TypeError);
        assert.equal(err.message, 'Invalid loan policy');
        assert.equal(err.code, 'INVALID_LOAN_POLICY');
        assert.deepEqual(err.errors, [{ path: field, code: 'INVALID_VALUE' }]);
      }
    });
  });
});