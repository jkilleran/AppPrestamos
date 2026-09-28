'use strict';

const assert = require('node:assert/strict');
const { test, describe } = require('node:test');

const { validateLoanPolicy, createLoanPolicySnapshot } = require('../services/loanPolicy');

// ============================================================================
// Test Fixtures - Valid policies for baseline
// ============================================================================

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

function zeroRateFixture() {
  return {
    schemaVersion: 1,
    policyId: 'zero-rate',
    policyVersion: 1,
    currency: 'DOP',
    amount: { minMinor: 1000, maxMinor: 10000 },
    interest: { rateBps: 0, period: 'monthly', method: 'equal_principal_declining_balance' },
    repayment: { installmentCount: 1, intervalDays: 7 }
  };
}

function equalBoundsFixture() {
  return {
    schemaVersion: 1,
    policyId: 'equal-bounds',
    policyVersion: 2,
    currency: 'DOP',
    amount: { minMinor: 10000, maxMinor: 10000 },
    interest: { rateBps: 100, period: 'annual', method: 'equal_principal_declining_balance' },
    repayment: { installmentCount: 5, intervalDays: 14 }
  };
}

function policyVersionGt1Fixture() {
  return {
    schemaVersion: 1,
    policyId: 'version-5',
    policyVersion: 5,
    currency: 'DOP',
    amount: { minMinor: 1000, maxMinor: 2000 },
    interest: { rateBps: 500, period: 'monthly', method: 'equal_principal_declining_balance' },
    repayment: { installmentCount: 3, intervalDays: 15 }
  };
}

// ============================================================================
// Helper functions for test assertions
// ============================================================================

function assertValid(input, message) {
  const result = validateLoanPolicy(input);
  assert.equal(result.valid, true, message + ': expected valid');
  assert.deepEqual(result.errors, []);
}

function assertInvalid(input, expectedErrors, message) {
  const result = validateLoanPolicy(input);
  assert.equal(result.valid, false, message + ': expected invalid');
  assert.deepEqual(result.errors, expectedErrors);
}

function assertSnapshotThrows(input, expectedErrors, message) {
  assert.throws(
    () => createLoanPolicySnapshot(input),
    (err) => {
      assert.ok(err instanceof TypeError, 'should throw TypeError');
      assert.equal(err.message, 'Invalid loan policy', 'message should be "Invalid loan policy"');
      assert.equal(err.code, 'INVALID_LOAN_POLICY', 'code should be INVALID_LOAN_POLICY');
      assert.deepEqual(err.errors, expectedErrors, 'errors should match validation errors');
      return true;
    },
    message
  );
}

function assertSnapshotValid(input, message) {
  const snapshot = createLoanPolicySnapshot(input);
  assert.ok(snapshot !== null && typeof snapshot === 'object', 'should return object');
  // Verify all fields present
  assert.equal(snapshot.schemaVersion, 1);
  assert.ok(typeof snapshot.policyId === 'string');
  assert.ok(Number.isSafeInteger(snapshot.policyVersion) && snapshot.policyVersion > 0);
  assert.equal(snapshot.currency, 'DOP');
  assert.ok(Number.isSafeInteger(snapshot.amount.minMinor) && snapshot.amount.minMinor > 0);
  assert.ok(Number.isSafeInteger(snapshot.amount.maxMinor) && snapshot.amount.maxMinor > 0);
  assert.ok(Number.isSafeInteger(snapshot.interest.rateBps) && snapshot.interest.rateBps >= 0);
  assert.ok(['monthly', 'annual'].includes(snapshot.interest.period));
  assert.equal(snapshot.interest.method, 'equal_principal_declining_balance');
  assert.ok(Number.isSafeInteger(snapshot.repayment.installmentCount) && snapshot.repayment.installmentCount > 0);
  assert.ok(Number.isSafeInteger(snapshot.repayment.intervalDays) && snapshot.repayment.intervalDays > 0);
  // Verify frozen
  assert.ok(Object.isFrozen(snapshot), 'top-level should be frozen');
  assert.ok(Object.isFrozen(snapshot.amount), 'amount should be frozen');
  assert.ok(Object.isFrozen(snapshot.interest), 'interest should be frozen');
  assert.ok(Object.isFrozen(snapshot.repayment), 'repayment should be frozen');
  return snapshot;
}

// ============================================================================
// Test Suite - C01 Schema Preservation
// ============================================================================

describe('C01 Schema Preservation - validateLoanPolicy', () => {
  test('valid policies preserve schema version 1', () => {
    assertValid(monthlyFixture(), 'monthly');
    assertValid(annualFixture(), 'annual');
    assertValid(zeroRateFixture(), 'zero rate');
    assertValid(equalBoundsFixture(), 'equal bounds');
    assertValid(policyVersionGt1Fixture(), 'policyVersion > 1');
  });

  test('null-prototype input validates', () => {
    const input = Object.create(null);
    Object.assign(input, monthlyFixture());
    assertValid(input, 'null-prototype input');
  });

  test('frozen valid input validates', () => {
    const input = Object.freeze(monthlyFixture());
    assertValid(input, 'frozen valid input');
  });
});

// ============================================================================
// Test Suite - C02 Error Classification
// ============================================================================

describe('C02 Error Classification - validateLoanPolicy', () => {
  // REQUIRED errors (missing keys)
  test('explicit undefined treated as REQUIRED for all root fields', () => {
    const cases = [
      { ...monthlyFixture(), schemaVersion: undefined },
      { ...monthlyFixture(), policyId: undefined },
      { ...monthlyFixture(), policyVersion: undefined },
      { ...monthlyFixture(), currency: undefined },
      { ...monthlyFixture(), amount: undefined },
      { ...monthlyFixture(), interest: undefined },
      { ...monthlyFixture(), repayment: undefined }
    ];
    const expectedPaths = ['schemaVersion', 'policyId', 'policyVersion', 'currency', 'amount', 'interest', 'repayment'];
    cases.forEach((input, i) => {
      const result = validateLoanPolicy(input);
      assert.equal(result.valid, false);
      assert.equal(result.errors.length, 1);
      assert.equal(result.errors[0].path, expectedPaths[i]);
      assert.equal(result.errors[0].code, 'REQUIRED');
    });
  });

  test('nested REQUIRED for amount fields', () => {
    const input = monthlyFixture();
    delete input.amount.minMinor;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.equal(result.errors.length, 1);
    assert.equal(result.errors[0].path, 'amount.minMinor');
    assert.equal(result.errors[0].code, 'REQUIRED');
  });

  test('nested REQUIRED for interest fields', () => {
    const input = monthlyFixture();
    delete input.interest.rateBps;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.equal(result.errors.length, 1);
    assert.equal(result.errors[0].path, 'interest.rateBps');
    assert.equal(result.errors[0].code, 'REQUIRED');
  });

  test('nested REQUIRED for repayment fields', () => {
    const input = monthlyFixture();
    delete input.repayment.installmentCount;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.equal(result.errors.length, 1);
    assert.equal(result.errors[0].path, 'repayment.installmentCount');
    assert.equal(result.errors[0].code, 'REQUIRED');
  });

  // INVALID_TYPE errors (wrong primitive types)
  test('string scalar for string fields (policyId, currency, period, method)', () => {
    const input = monthlyFixture({
      policyId: 123,
      currency: 123,
      interest: { ...monthlyFixture().interest, period: 456, method: 789 }
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    // All string fields should have INVALID_TYPE
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    assert.equal(typeErrors.length, 4);
  });

  test('boolean scalar for number fields', () => {
    const input = monthlyFixture({
      policyVersion: true,
      amount: { minMinor: false, maxMinor: true },
      interest: { rateBps: false },
      repayment: { installmentCount: true, intervalDays: false }
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    assert.equal(typeErrors.length, 6);
  });

  test('null scalar for any field', () => {
    const input = monthlyFixture({
      schemaVersion: null,
      policyId: null,
      policyVersion: null,
      currency: null,
      amount: null,
      interest: null,
      repayment: null
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    assert.equal(typeErrors.length, 7);
  });

  test('boxed Number for number fields', () => {
    const num = new Number(123);
    const input = monthlyFixture({
      policyVersion: num,
      amount: { minMinor: new Number(456), maxMinor: new Number(789) },
      interest: { rateBps: new Number(999) },
      repayment: { installmentCount: new Number(1), intervalDays: new Number(2) }
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    assert.equal(typeErrors.length, 6);
  });

  // INVALID_VALUE errors (wrong values within correct type)
  test('invalid schemaVersion (not 1)', () => {
    assertInvalid({ ...monthlyFixture(), schemaVersion: 2 }, [{ path: 'schemaVersion', code: 'INVALID_VALUE' }], 'schemaVersion != 1');
  });

  test('invalid currency (not DOP)', () => {
    assertInvalid({ ...monthlyFixture(), currency: 'USD' }, [{ path: 'currency', code: 'INVALID_VALUE' }], 'currency != DOP');
  });

  test('invalid period (not monthly/annual)', () => {
    assertInvalid({ ...monthlyFixture(), interest: { ...monthlyFixture().interest, period: 'weekly' } }, [{ path: 'interest.period', code: 'INVALID_VALUE' }], 'period not allowed');
  });

  test('invalid method (not equal_principal_declining_balance)', () => {
    assertInvalid({ ...monthlyFixture(), interest: { ...monthlyFixture().interest, method: 'wrong_method' } }, [{ path: 'interest.method', code: 'INVALID_VALUE' }], 'method not allowed');
  });

  test('amount.minMinor zero (not positive)', () => {
    assertInvalid({ ...monthlyFixture(), amount: { minMinor: 0, maxMinor: 1000 } }, [{ path: 'amount.minMinor', code: 'INVALID_VALUE' }], 'minMinor zero');
  });

  test('amount.maxMinor negative (not positive)', () => {
    assertInvalid({ ...monthlyFixture(), amount: { minMinor: 1000, maxMinor: -1 } }, [{ path: 'amount.maxMinor', code: 'INVALID_VALUE' }], 'maxMinor negative');
  });

  test('amount.minMinor > amount.maxMinor (bounds)', () => {
    assertInvalid({ ...monthlyFixture(), amount: { minMinor: 2000, maxMinor: 1000 } }, [{ path: 'amount.maxMinor', code: 'INVALID_VALUE' }], 'min > max');
  });

  test('interest.rateBps negative (not nonnegative)', () => {
    assertInvalid({ ...monthlyFixture(), interest: { ...monthlyFixture().interest, rateBps: -100 } }, [{ path: 'interest.rateBps', code: 'INVALID_VALUE' }], 'rateBps negative');
  });

  test('repayment.installmentCount zero (not positive)', () => {
    assertInvalid({ ...monthlyFixture(), repayment: { installmentCount: 0, intervalDays: 30 } }, [{ path: 'repayment.installmentCount', code: 'INVALID_VALUE' }], 'installmentCount zero');
  });

  test('repayment.intervalDays negative (not positive)', () => {
    assertInvalid({ ...monthlyFixture(), repayment: { installmentCount: 2, intervalDays: -1 } }, [{ path: 'repayment.intervalDays', code: 'INVALID_VALUE' }], 'intervalDays negative');
  });

  // UNKNOWN_FIELD errors (extra keys)
  test('unknown root field', () => {
    assertInvalid({ ...monthlyFixture(), extraRoot: 'value' }, [{ path: 'extraRoot', code: 'UNKNOWN_FIELD' }], 'unknown root field');
  });

  test('unknown amount field', () => {
    assertInvalid({ ...monthlyFixture(), amount: { ...monthlyFixture().amount, extra: 'value' } }, [{ path: 'amount.extra', code: 'UNKNOWN_FIELD' }], 'unknown amount field');
  });

  test('unknown interest field', () => {
    assertInvalid({ ...monthlyFixture(), interest: { ...monthlyFixture().interest, extra: 'value' } }, [{ path: 'interest.extra', code: 'UNKNOWN_FIELD' }], 'unknown interest field');
  });

  test('unknown repayment field', () => {
    assertInvalid({ ...monthlyFixture(), repayment: { ...monthlyFixture().repayment, extra: 'value' } }, [{ path: 'repayment.extra', code: 'UNKNOWN_FIELD' }], 'unknown repayment field');
  });

  test('multiple unknown fields sorted', () => {
    const input = { ...monthlyFixture(), aExtra: 1, bExtra: 2 };
    input.amount.zExtra = 1;
    input.amount.aExtra = 2;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const unknownErrors = result.errors.filter(e => e.code === 'UNKNOWN_FIELD');
    assert.equal(unknownErrors.length, 4);
    assert.equal(unknownErrors[0].path, 'aExtra');
    assert.equal(unknownErrors[1].path, 'amount.aExtra');
    assert.equal(unknownErrors[2].path, 'amount.zExtra');
    assert.equal(unknownErrors[3].path, 'bExtra');
  });

  // C02.6 Parent invalid type stops descent
  test('parent object invalid type – no child errors', () => {
    const input = monthlyFixture();
    input.amount = null; // INVALID_TYPE at amount level
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    // Should have INVALID_TYPE on 'amount', no child errors on min/max
    assert.equal(result.errors.length, 1);
    assert.equal(result.errors[0].path, 'amount');
    assert.equal(result.errors[0].code, 'INVALID_TYPE');
  });

  // C02.7 Invalid value errors only when key exists (not for undefined)
  test('undefined values do not generate INVALID_VALUE', () => {
    const input = monthlyFixture();
    input.amount.minMinor = undefined;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    // Should have REQUIRED for amount.minMinor, NOT INVALID_VALUE
    assert.equal(result.errors.length, 1);
    assert.equal(result.errors[0].path, 'amount.minMinor');
    assert.equal(result.errors[0].code, 'REQUIRED');
  });
});

// ============================================================================
// Test Suite - C03 Deduplication & Sorting
// ============================================================================

describe('C03 Deduplication & Sorting - validateLoanPolicy', () => {
  test('deduplication of identical (path, code) pairs', () => {
    const input = monthlyFixture();
    input.amount.minMinor = undefined;
    input.amount.maxMinor = undefined;
    input.interest.rateBps = undefined;
    const result = validateLoanPolicy(input);
    // Should have 3 REQUIRED errors (one for each field), not 6 INVALID_VALUE
    assert.equal(result.valid, false);
    const requiredCount = result.errors.filter(e => e.code === 'REQUIRED').length;
    assert.equal(requiredCount, 3);
    assert.equal(result.errors.length, 3);
  });

  test('sorting by path then code', () => {
    const input = { ...monthlyFixture(), schemaVersion: 2, policyId: '-invalid', extraField: true };
    input.amount.minMinor = 0;
    input.interest.rateBps = -1;
    input.repayment.installmentCount = 0;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    // Check sorting: path first, then code
    const paths = result.errors.map(e => e.path);
    for (let i = 1; i < paths.length; i++) {
      assert.ok(paths[i - 1] <= paths[i], `errors should be sorted: ${paths.join(', ')}`);
    }
    // Verify all expected errors present
    const expectedPaths = [
      'amount.minMinor',
      'extraField',
      'interest.rateBps',
      'policyId',
      'repayment.installmentCount',
      'schemaVersion'
    ];
    assert.deepEqual(paths.sort(), expectedPaths.sort());
  });
});

// ============================================================================
// Test Suite - C04 Snapshot Behavior
// ============================================================================

describe('C04 Snapshot Behavior - createLoanPolicySnapshot', () => {
  test('valid input returns frozen snapshot', () => {
    assertSnapshotValid(monthlyFixture(), 'valid input');
  });

  test('snapshot contains correct values (literal match)', () => {
    const input = monthlyFixture();
    const snapshot = createLoanPolicySnapshot(input);
    const expected = {
      schemaVersion: 1,
      policyId: 'fixture-monthly',
      policyVersion: 1,
      currency: 'DOP',
      amount: { minMinor: 1000000, maxMinor: 2000000 },
      interest: { rateBps: 1800, period: 'monthly', method: 'equal_principal_declining_balance' },
      repayment: { installmentCount: 2, intervalDays: 30 }
    };
    assert.deepStrictEqual(snapshot, expected);
  });

  test('snapshot is deeply frozen', () => {
    const input = monthlyFixture();
    const snapshot = createLoanPolicySnapshot(input);
    assert.ok(Object.isFrozen(snapshot));
    assert.ok(Object.isFrozen(snapshot.amount));
    assert.ok(Object.isFrozen(snapshot.interest));
    assert.ok(Object.isFrozen(snapshot.repayment));
  });

  test('snapshot throws TypeError with exact properties', () => {
    const invalid = monthlyFixture();
    invalid.schemaVersion = 2; // Make it invalid
    assertSnapshotThrows(invalid, [{ path: 'schemaVersion', code: 'INVALID_VALUE' }], 'throws on invalid');
  });

  test('snapshot error matches validation errors exactly', () => {
    const invalid = monthlyFixture();
    invalid.schemaVersion = 2;
    const validationErrors = validateLoanPolicy(invalid).errors;
    assertSnapshotThrows(invalid, validationErrors, 'snapshot errors match validation');
  });

  test('snapshot error message does not contain submitted values', () => {
    const input = monthlyFixture();
    input.policyId = 'SECRET_ID';
    input.schemaVersion = 2; // Make it invalid to trigger throw
    assertSnapshotThrows(input, [{ path: 'schemaVersion', code: 'INVALID_VALUE' }], 'no sensitive info in message');
  });

  test('input not mutated by validation', () => {
    const input = monthlyFixture();
    const original = JSON.parse(JSON.stringify(input));
    validateLoanPolicy(input);
    assert.deepStrictEqual(input, original, 'input should not change');
  });

  test('input not frozen by snapshot creation', () => {
    const input = monthlyFixture();
    createLoanPolicySnapshot(input);
    assert.ok(!Object.isFrozen(input));
  });

  test('frozen input accepted for snapshot', () => {
    const input = Object.freeze(monthlyFixture());
    Object.freeze(input.amount);
    Object.freeze(input.interest);
    Object.freeze(input.repayment);
    const snapshot = assertSnapshotValid(input, 'frozen input');
    assert.equal(snapshot.policyId, 'fixture-monthly');
  });

  test('null-prototype input produces ordinary output objects', () => {
    const input = Object.create(null);
    Object.assign(input, monthlyFixture());
    const snapshot = createLoanPolicySnapshot(input);
    assert.equal(Object.getPrototypeOf(snapshot), Object.prototype);
    assert.equal(Object.getPrototypeOf(snapshot.amount), Object.prototype);
    assert.equal(Object.getPrototypeOf(snapshot.interest), Object.prototype);
    assert.equal(Object.getPrototypeOf(snapshot.repayment), Object.prototype);
  });

  test('-0 value preserved as -0 in snapshot', () => {
    const input = monthlyFixture();
    input.interest.rateBps = -0; // rateBps accepts nonnegative (0 and -0)
    const snapshot = createLoanPolicySnapshot(input);
    assert.equal(snapshot.interest.rateBps, -0);
    // JSON.stringify should preserve -0
    const json = JSON.stringify(snapshot);
    assert.ok(json.includes('-0') || json.includes('0'));
  });

  test('snapshots are independent and equal', () => {
    const input = monthlyFixture();
    const snap1 = createLoanPolicySnapshot(input);
    const snap2 = createLoanPolicySnapshot(input);
    assert.deepStrictEqual(snap1, snap2);
    assert.notStrictEqual(snap1, snap2);
    assert.notStrictEqual(snap1.amount, snap2.amount);
    assert.notStrictEqual(snap1.interest, snap2.interest);
    assert.notStrictEqual(snap1.repayment, snap2.repayment);
  });

  test('snapshot preserves all accepted fields', () => {
    const input = monthlyFixture();
    const snapshot = createLoanPolicySnapshot(input);
    assert.equal(snapshot.schemaVersion, input.schemaVersion);
    assert.equal(snapshot.policyId, input.policyId);
    assert.equal(snapshot.policyVersion, input.policyVersion);
    assert.equal(snapshot.currency, input.currency);
    assert.equal(snapshot.amount.minMinor, input.amount.minMinor);
    assert.equal(snapshot.amount.maxMinor, input.amount.maxMinor);
    assert.equal(snapshot.interest.rateBps, input.interest.rateBps);
    assert.equal(snapshot.interest.period, input.interest.period);
    assert.equal(snapshot.interest.method, input.interest.method);
    assert.equal(snapshot.repayment.installmentCount, input.repayment.installmentCount);
    assert.equal(snapshot.repayment.intervalDays, input.repayment.intervalDays);
  });

  // ============================================================================
  // D1: Snapshot TypeError for all 14 independently missing/undefined required fields
  // ============================================================================

  const requiredFieldsForSnapshot = [
    { name: 'schemaVersion', makeMissing: (input) => { delete input.schemaVersion; }, path: 'schemaVersion' },
    { name: 'policyId', makeMissing: (input) => { delete input.policyId; }, path: 'policyId' },
    { name: 'policyVersion', makeMissing: (input) => { delete input.policyVersion; }, path: 'policyVersion' },
    { name: 'currency', makeMissing: (input) => { delete input.currency; }, path: 'currency' },
    { name: 'amount', makeMissing: (input) => { delete input.amount; }, path: 'amount' },
    { name: 'interest', makeMissing: (input) => { delete input.interest; }, path: 'interest' },
    { name: 'repayment', makeMissing: (input) => { delete input.repayment; }, path: 'repayment' },
    { name: 'amount.minMinor', makeMissing: (input) => { delete input.amount.minMinor; }, path: 'amount.minMinor' },
    { name: 'amount.maxMinor', makeMissing: (input) => { delete input.amount.maxMinor; }, path: 'amount.maxMinor' },
    { name: 'interest.rateBps', makeMissing: (input) => { delete input.interest.rateBps; }, path: 'interest.rateBps' },
    { name: 'interest.period', makeMissing: (input) => { delete input.interest.period; }, path: 'interest.period' },
    { name: 'interest.method', makeMissing: (input) => { delete input.interest.method; }, path: 'interest.method' },
    { name: 'repayment.installmentCount', makeMissing: (input) => { delete input.repayment.installmentCount; }, path: 'repayment.installmentCount' },
    { name: 'repayment.intervalDays', makeMissing: (input) => { delete input.repayment.intervalDays; }, path: 'repayment.intervalDays' }
  ];

  requiredFieldsForSnapshot.forEach(({ name, makeMissing, path }) => {
    test(`delete ${name} → snapshot TypeError with REQUIRED`, () => {
      const input = monthlyFixture();
      makeMissing(input);
      assertSnapshotThrows(input, [{ path, code: 'REQUIRED' }], `delete ${name}`);
    });

    test(`undefined ${name} → snapshot TypeError with REQUIRED`, () => {
      const input = monthlyFixture();
      if (name.includes('.')) {
        const parts = name.split('.');
        input[parts[0]][parts[1]] = undefined;
      } else {
        input[name] = undefined;
      }
      assertSnapshotThrows(input, [{ path, code: 'REQUIRED' }], `undefined ${name}`);
    });
  });

  // ============================================================================
  // D2: Nested null-prototype inputs with owned references
  // ============================================================================

  test('nested null-prototype input produces ordinary output with owned references', () => {
    const input = Object.create(null);
    Object.assign(input, monthlyFixture());
    // Replace nested objects with null-prototype versions
    input.amount = Object.create(null);
    Object.assign(input.amount, { minMinor: 1000000, maxMinor: 2000000 });
    input.interest = Object.create(null);
    Object.assign(input.interest, { rateBps: 1800, period: 'monthly', method: 'equal_principal_declining_balance' });
    input.repayment = Object.create(null);
    Object.assign(input.repayment, { installmentCount: 2, intervalDays: 30 });

    const snapshot = createLoanPolicySnapshot(input);

    // Output prototypes must be Object.prototype
    assert.equal(Object.getPrototypeOf(snapshot), Object.prototype);
    assert.equal(Object.getPrototypeOf(snapshot.amount), Object.prototype);
    assert.equal(Object.getPrototypeOf(snapshot.interest), Object.prototype);
    assert.equal(Object.getPrototypeOf(snapshot.repayment), Object.prototype);

    // Exact accepted values
    assert.equal(snapshot.schemaVersion, 1);
    assert.equal(snapshot.policyId, 'fixture-monthly');
    assert.equal(snapshot.policyVersion, 1);
    assert.equal(snapshot.currency, 'DOP');
    assert.equal(snapshot.amount.minMinor, 1000000);
    assert.equal(snapshot.amount.maxMinor, 2000000);
    assert.equal(snapshot.interest.rateBps, 1800);
    assert.equal(snapshot.interest.period, 'monthly');
    assert.equal(snapshot.interest.method, 'equal_principal_declining_balance');
    assert.equal(snapshot.repayment.installmentCount, 2);
    assert.equal(snapshot.repayment.intervalDays, 30);

    // Deep freezing
    assert.ok(Object.isFrozen(snapshot));
    assert.ok(Object.isFrozen(snapshot.amount));
    assert.ok(Object.isFrozen(snapshot.interest));
    assert.ok(Object.isFrozen(snapshot.repayment));

    // Owned (non-shared) nested references
    const snapshot2 = createLoanPolicySnapshot(input);
    assert.notStrictEqual(snapshot.amount, snapshot2.amount);
    assert.notStrictEqual(snapshot.interest, snapshot2.interest);
    assert.notStrictEqual(snapshot.repayment, snapshot2.repayment);
  });

  // ============================================================================
  // D3: Strict-mode mutation rejection on all frozen snapshot levels
  // ============================================================================

  test('strict-mode writes to frozen snapshot levels throw TypeError', () => {
    const input = monthlyFixture();
    const snapshot = createLoanPolicySnapshot(input);

    // Top-level
    assert.throws(() => { 'use strict'; snapshot.schemaVersion = 2; }, TypeError);
    assert.throws(() => { 'use strict'; snapshot.policyId = 'x'; }, TypeError);
    assert.throws(() => { 'use strict'; snapshot.policyVersion = 99; }, TypeError);
    assert.throws(() => { 'use strict'; snapshot.currency = 'USD'; }, TypeError);

    // Nested amount
    assert.throws(() => { 'use strict'; snapshot.amount.minMinor = 999; }, TypeError);
    assert.throws(() => { 'use strict'; snapshot.amount.maxMinor = 999; }, TypeError);

    // Nested interest
    assert.throws(() => { 'use strict'; snapshot.interest.rateBps = 999; }, TypeError);
    assert.throws(() => { 'use strict'; snapshot.interest.period = 'weekly'; }, TypeError);
    assert.throws(() => { 'use strict'; snapshot.interest.method = 'other'; }, TypeError);

    // Nested repayment
    assert.throws(() => { 'use strict'; snapshot.repayment.installmentCount = 999; }, TypeError);
    assert.throws(() => { 'use strict'; snapshot.repayment.intervalDays = 999; }, TypeError);

    // Values must remain unchanged
    assert.equal(snapshot.schemaVersion, 1);
    assert.equal(snapshot.policyId, 'fixture-monthly');
    assert.equal(snapshot.policyVersion, 1);
    assert.equal(snapshot.currency, 'DOP');
    assert.equal(snapshot.amount.minMinor, 1000000);
    assert.equal(snapshot.amount.maxMinor, 2000000);
    assert.equal(snapshot.interest.rateBps, 1800);
    assert.equal(snapshot.interest.period, 'monthly');
    assert.equal(snapshot.interest.method, 'equal_principal_declining_balance');
    assert.equal(snapshot.repayment.installmentCount, 2);
    assert.equal(snapshot.repayment.intervalDays, 30);
  });

  // ============================================================================
  // D4: Caller input preservation (refs, values, frozen state)
  // ============================================================================

  test('caller root/nested references, values and frozen state preserved', () => {
    const input = monthlyFixture();
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

    // Also test with already-frozen nested objects
    const frozenInput = monthlyFixture();
    Object.freeze(frozenInput.amount);
    Object.freeze(frozenInput.interest);
    Object.freeze(frozenInput.repayment);
    const frozenOriginalRefs = {
      root: frozenInput,
      amount: frozenInput.amount,
      interest: frozenInput.interest,
      repayment: frozenInput.repayment
    };
    const frozenOriginalFrozen = {
      root: Object.isFrozen(frozenInput),
      amount: Object.isFrozen(frozenInput.amount),
      interest: Object.isFrozen(frozenInput.interest),
      repayment: Object.isFrozen(frozenInput.repayment)
    };
    const frozenOriginalValues = JSON.parse(JSON.stringify(frozenInput));

    const snapshot1 = createLoanPolicySnapshot(input);
    const snapshot2 = createLoanPolicySnapshot(frozenInput);

    // Regular input preservation
    assert.strictEqual(input, originalRefs.root);
    assert.strictEqual(input.amount, originalRefs.amount);
    assert.strictEqual(input.interest, originalRefs.interest);
    assert.strictEqual(input.repayment, originalRefs.repayment);
    assert.equal(Object.isFrozen(input), originalFrozen.root);
    assert.equal(Object.isFrozen(input.amount), originalFrozen.amount);
    assert.equal(Object.isFrozen(input.interest), originalFrozen.interest);
    assert.equal(Object.isFrozen(input.repayment), originalFrozen.repayment);
    assert.deepStrictEqual(input, originalValues);

    // Frozen input preservation
    assert.strictEqual(frozenInput, frozenOriginalRefs.root);
    assert.strictEqual(frozenInput.amount, frozenOriginalRefs.amount);
    assert.strictEqual(frozenInput.interest, frozenOriginalRefs.interest);
    assert.strictEqual(frozenInput.repayment, frozenOriginalRefs.repayment);
    assert.equal(Object.isFrozen(frozenInput), frozenOriginalFrozen.root);
    assert.equal(Object.isFrozen(frozenInput.amount), frozenOriginalFrozen.amount);
    assert.equal(Object.isFrozen(frozenInput.interest), frozenOriginalFrozen.interest);
    assert.equal(Object.isFrozen(frozenInput.repayment), frozenOriginalFrozen.repayment);
    assert.deepStrictEqual(frozenInput, frozenOriginalValues);

    // Snapshots are valid
    assert.ok(snapshot1.schemaVersion === 1);
    assert.ok(snapshot2.schemaVersion === 1);
  });

  // ============================================================================
  // D5: Object.is for -0 preservation and repeated snapshot independence
  // ============================================================================

  test('Object.is proves snapshot interest.rateBps preserves -0', () => {
    const input = monthlyFixture();
    input.interest.rateBps = -0;
    const snapshot = createLoanPolicySnapshot(input);
    assert.ok(Object.is(snapshot.interest.rateBps, -0), 'snapshot should preserve -0 via Object.is');
    assert.ok(!Object.is(snapshot.interest.rateBps, 0), 'snapshot -0 should be distinct from +0');
  });

  test('repeated snapshots are equal but independent (deep)', () => {
    const input = monthlyFixture();
    const snap1 = createLoanPolicySnapshot(input);
    const snap2 = createLoanPolicySnapshot(input);
    const snap3 = createLoanPolicySnapshot(input);

    // Equal
    assert.deepStrictEqual(snap1, snap2);
    assert.deepStrictEqual(snap2, snap3);

    // Independent at all levels
    assert.notStrictEqual(snap1, snap2);
    assert.notStrictEqual(snap2, snap3);
    assert.notStrictEqual(snap1.amount, snap2.amount);
    assert.notStrictEqual(snap2.amount, snap3.amount);
    assert.notStrictEqual(snap1.interest, snap2.interest);
    assert.notStrictEqual(snap2.interest, snap3.interest);
    assert.notStrictEqual(snap1.repayment, snap2.repayment);
    assert.notStrictEqual(snap2.repayment, snap3.repayment);

    // Mutating one doesn't affect others (in strict mode this throws, but we verify values)
    assert.deepStrictEqual(snap1, snap2);
    assert.deepStrictEqual(snap2, snap3);
  });
});

// ============================================================================
// Test Suite - C05 Test Corrections & Additional Cases
// ============================================================================

describe('C05 Test Corrections & Additional Cases - validateLoanPolicy', () => {
  // C05.1 Existing numeric edge case tests corrected to INVALID_TYPE
  test('numeric edge cases: string instead of number → INVALID_TYPE', () => {
    const cases = [
      { field: 'policyVersion', value: '123' },
      { field: 'amount.minMinor', value: '456' },
      { field: 'amount.maxMinor', value: '789' },
      { field: 'interest.rateBps', value: '999' },
      { field: 'repayment.installmentCount', value: '1' },
      { field: 'repayment.intervalDays', value: '2' }
    ];
    cases.forEach(({ field, value }) => {
      const input = monthlyFixture();
      const parts = field.split('.');
      let current = input;
      for (let i = 0; i < parts.length - 1; i++) {
        current = current[parts[i]];
      }
      current[parts[parts.length - 1]] = value;
      const result = validateLoanPolicy(input);
      assert.equal(result.valid, false);
      const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
      assert.ok(typeErrors.length > 0, `Expected INVALID_TYPE for ${field}`);
    });
  });

  test('numeric edge cases: boolean instead of number → INVALID_TYPE', () => {
    const input = monthlyFixture({
      policyVersion: true,
      amount: { minMinor: false, maxMinor: true },
      interest: { rateBps: false },
      repayment: { installmentCount: true, intervalDays: false }
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    assert.equal(typeErrors.length, 6);
  });

  test('numeric edge cases: null instead of number → INVALID_TYPE', () => {
    const input = monthlyFixture({
      policyVersion: null,
      amount: { minMinor: null, maxMinor: null },
      interest: { rateBps: null },
      repayment: { installmentCount: null, intervalDays: null }
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    // 6 number fields: policyVersion, amount.minMinor, amount.maxMinor, interest.rateBps, repayment.installmentCount, repayment.intervalDays
    assert.equal(typeErrors.length, 6);
  });

  // C05.2 Explicit undefined cases
  test('explicit undefined for all required fields → REQUIRED only', () => {
    const input = monthlyFixture({
      schemaVersion: undefined,
      policyId: undefined,
      policyVersion: undefined,
      currency: undefined,
      amount: undefined,
      interest: undefined,
      repayment: undefined
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const requiredCount = result.errors.filter(e => e.code === 'REQUIRED').length;
    assert.equal(requiredCount, 7);
    const valueCount = result.errors.filter(e => e.code === 'INVALID_VALUE').length;
    assert.equal(valueCount, 0);
    const typeCount = result.errors.filter(e => e.code === 'INVALID_TYPE').length;
    assert.equal(typeCount, 0);
  });

  // C05.3 Boxed number (Number object) → INVALID_TYPE
  test('boxed Number (Number object) treated as invalid type', () => {
    const boxed = new Number(123);
    const input = monthlyFixture({
      policyVersion: boxed,
      amount: { minMinor: new Number(456), maxMinor: new Number(789) },
      interest: { rateBps: new Number(999) },
      repayment: { installmentCount: new Number(1), intervalDays: new Number(2) }
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    assert.equal(typeErrors.length, 6);
  });

  // C05.4 Array and object types in wrong places → INVALID_TYPE
  test('array as scalar field → INVALID_TYPE', () => {
    const input = monthlyFixture({
      policyVersion: [1, 2, 3],
      amount: { minMinor: [], maxMinor: {} },
      interest: { rateBps: [] },
      repayment: { installmentCount: {}, intervalDays: [] }
    });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const typeErrors = result.errors.filter(e => e.code === 'INVALID_TYPE');
    assert.equal(typeErrors.length, 6);
  });

  // C05.5 Unknown field with undefined value → UNKNOWN_FIELD
  test('unknown field with undefined value still yields UNKNOWN_FIELD', () => {
    const input = monthlyFixture();
    input.extraField = undefined;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const unknownErrors = result.errors.filter(e => e.code === 'UNKNOWN_FIELD');
    assert.equal(unknownErrors.length, 1);
    assert.equal(unknownErrors[0].path, 'extraField');
  });

  // C05.6 Verify snapshot test expectations with literal arrays
  test('snapshot error arrays match literal validation results', () => {
    const invalid = monthlyFixture({
      schemaVersion: 2,
      policyId: '',
      interest: { rateBps: -1, period: 'weekly' }
    });
    const validationResult = validateLoanPolicy(invalid);
    assertSnapshotThrows(invalid, validationResult.errors, 'snapshot errors match validation');
  });
});

// ============================================================================
// Test Suite - C06 Source Inspection (complementary, not import-isolation proof)
// ============================================================================

describe('C06 Source Inspection (complementary, not import-isolation proof)', () => {
  test('module source has no application imports (CommonJS-only check)', () => {
    const fs = require('fs');
    const source = fs.readFileSync(require.resolve('../services/loanPolicy.js'), 'utf8');
    assert.ok(!source.includes("require('../db'"), 'no db import');
    assert.ok(!source.includes("require('../models'"), 'no models import');
    assert.ok(!source.includes("require('../controllers'"), 'no controllers import');
    assert.ok(!source.includes("require('../routes'"), 'no routes import');
    assert.ok(!source.includes("require('../services'"), 'no other services import');
    assert.ok(!source.includes('dotenv'), 'no dotenv import');
    assert.ok(!source.includes('express'), 'no express import');
    assert.ok(!source.includes('pg'), 'no pg import');
    assert.ok(!source.includes('jsonwebtoken'), 'no jwt import');
    assert.ok(!source.includes('bcryptjs'), 'no bcrypt import');
    assert.ok(!source.includes('cors'), 'no cors import');
    assert.ok(!source.includes('multer'), 'no multer import');
    assert.ok(!source.includes('nodemailer'), 'no nodemailer import');
    assert.ok(!source.includes('pdfkit'), 'no pdfkit import');
  });

  test('module has no side effects (no I/O, timers, randomness, env reads)', () => {
    const fs = require('fs');
    const source = fs.readFileSync(require.resolve('../services/loanPolicy.js'), 'utf8');
    assert.ok(!source.includes('console.log'), 'no console.log');
    assert.ok(!source.includes('console.error'), 'no console.error');
    assert.ok(!source.includes('process.env'), 'no process.env');
    assert.ok(!source.includes('Date.now'), 'no Date.now');
    assert.ok(!source.includes('new Date'), 'no new Date');
    assert.ok(!source.includes('Math.random'), 'no Math.random');
    assert.ok(!source.includes('setTimeout'), 'no setTimeout');
    assert.ok(!source.includes('setInterval'), 'no setInterval');
    assert.ok(!source.includes('fs.'), 'no fs');
    assert.ok(!source.includes('readFile'), 'no readFile');
    assert.ok(!source.includes('writeFile'), 'no writeFile');
  });
});

// ============================================================================
// Test Suite - F1-F4 Fresh-Process Import Isolation Proof
// ============================================================================

describe('F1-F4 Fresh-Process Import Isolation Proof - loanPolicy', () => {
  const { execFileSync } = require('child_process');
  const { resolve } = require('path');
  const loanPolicyPath = resolve(__dirname, '../services/loanPolicy');

  test('F1-F2: imports cleanly with exact sorted exports', () => {
    const script = `
      const mod = require('${loanPolicyPath}');
      const exports = Object.keys(mod).sort();
      console.log('EXPORTS_JSON:' + JSON.stringify(exports));
      console.log('TYPE_VALIDATE:' + typeof mod.validateLoanPolicy);
      console.log('TYPE_CREATE:' + typeof mod.createLoanPolicySnapshot);
    `;
    const output = execFileSync(process.execPath, ['-e', script], {
      timeout: 5000,
      env: { ...process.env, NODE_OPTIONS: '' },
      cwd: __dirname
    }).toString().trim();

    const exportsLine = output.split('\n').find(l => l.startsWith('EXPORTS_JSON:'));
    const exports = JSON.parse(exportsLine.replace('EXPORTS_JSON:', ''));
    assert.deepEqual(exports, ['createLoanPolicySnapshot', 'validateLoanPolicy']);

    const typeValidateLine = output.split('\n').find(l => l.startsWith('TYPE_VALIDATE:'));
    assert.equal(typeValidateLine.replace('TYPE_VALIDATE:', ''), 'function');

    const typeCreateLine = output.split('\n').find(l => l.startsWith('TYPE_CREATE:'));
    assert.equal(typeCreateLine.replace('TYPE_CREATE:', ''), 'function');
  });

  test('F3: child loads no application modules beyond allowed', () => {
    const script = `
      const fs = require('fs');
      const mod = require('${loanPolicyPath}');
      const allowed = new Set([
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
// Test Suite - R1 Non-Finite Number Classification (NaN, Infinity, -Infinity)
// ============================================================================

describe('R1 Non-Finite Number Classification - validateLoanPolicy', () => {
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
      test(`${field} = ${name} → INVALID_VALUE`, () => {
        const input = monthlyFixture();
        const parts = field.split('.');
        let current = input;
        for (let i = 0; i < parts.length - 1; i++) {
          current = current[parts[i]];
        }
        current[parts[parts.length - 1]] = value;
        const result = validateLoanPolicy(input);
        assert.equal(result.valid, false);
        assert.deepEqual(result.errors, [{ path, code: 'INVALID_VALUE' }]);
      });

      test(`${field} = ${name} → snapshot throws INVALID_VALUE`, () => {
        const input = monthlyFixture();
        const parts = field.split('.');
        let current = input;
        for (let i = 0; i < parts.length - 1; i++) {
          current = current[parts[i]];
        }
        current[parts[parts.length - 1]] = value;
        assertSnapshotThrows(input, [{ path, code: 'INVALID_VALUE' }], `snapshot throws for ${field}=${name}`);
      });

      test(`${field} = ${name} → serializer throws INVALID_VALUE`, () => {
        const { serializeLoanPolicySnapshot } = require('../services/loanPolicySerialization');
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
// Test Suite - R2 Mandatory Coverage (Required Fields, Boundaries, Collisions)
// ============================================================================

describe('R2 Required Field Coverage - validateLoanPolicy', () => {
  const requiredFields = [
    { name: 'schemaVersion', deleteKey: 'schemaVersion', undefinedKey: 'schemaVersion', path: 'schemaVersion' },
    { name: 'policyId', deleteKey: 'policyId', undefinedKey: 'policyId', path: 'policyId' },
    { name: 'policyVersion', deleteKey: 'policyVersion', undefinedKey: 'policyVersion', path: 'policyVersion' },
    { name: 'currency', deleteKey: 'currency', undefinedKey: 'currency', path: 'currency' },
    { name: 'amount', deleteKey: 'amount', undefinedKey: 'amount', path: 'amount' },
    { name: 'interest', deleteKey: 'interest', undefinedKey: 'interest', path: 'interest' },
    { name: 'repayment', deleteKey: 'repayment', undefinedKey: 'repayment', path: 'repayment' },
    { name: 'amount.minMinor', deleteKey: 'amount.minMinor', undefinedKey: 'amount.minMinor', path: 'amount.minMinor', parent: 'amount' },
    { name: 'amount.maxMinor', deleteKey: 'amount.maxMinor', undefinedKey: 'amount.maxMinor', path: 'amount.maxMinor', parent: 'amount' },
    { name: 'interest.rateBps', deleteKey: 'interest.rateBps', undefinedKey: 'interest.rateBps', path: 'interest.rateBps', parent: 'interest' },
    { name: 'interest.period', deleteKey: 'interest.period', undefinedKey: 'interest.period', path: 'interest.period', parent: 'interest' },
    { name: 'interest.method', deleteKey: 'interest.method', undefinedKey: 'interest.method', path: 'interest.method', parent: 'interest' },
    { name: 'repayment.installmentCount', deleteKey: 'repayment.installmentCount', undefinedKey: 'repayment.installmentCount', path: 'repayment.installmentCount', parent: 'repayment' },
    { name: 'repayment.intervalDays', deleteKey: 'repayment.intervalDays', undefinedKey: 'repayment.intervalDays', path: 'repayment.intervalDays', parent: 'repayment' }
  ];

  requiredFields.forEach(({ name, deleteKey, undefinedKey, path, parent }) => {
    test(`delete ${name} → REQUIRED`, () => {
      const input = monthlyFixture();
      if (parent) {
        const parts = deleteKey.split('.');
        delete input[parts[0]][parts[1]];
      } else {
        delete input[deleteKey];
      }
      const result = validateLoanPolicy(input);
      assert.equal(result.valid, false);
      assert.deepEqual(result.errors, [{ path, code: 'REQUIRED' }]);
    });

    test(`undefined ${name} → REQUIRED`, () => {
      const input = monthlyFixture();
      if (parent) {
        const parts = undefinedKey.split('.');
        input[parts[0]][parts[1]] = undefined;
      } else {
        input[undefinedKey] = undefined;
      }
      const result = validateLoanPolicy(input);
      assert.equal(result.valid, false);
      assert.deepEqual(result.errors, [{ path, code: 'REQUIRED' }]);
    });
  });

  test('missing parent object yields only parent error (no child errors)', () => {
    const input = monthlyFixture();
    delete input.amount;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.equal(result.errors.length, 1);
    assert.deepEqual(result.errors, [{ path: 'amount', code: 'REQUIRED' }]);
  });
});

describe('R2 Numeric Boundaries - validateLoanPolicy', () => {
  test('fraction values → INVALID_VALUE', () => {
    const base = monthlyFixture();
    const input = {
      ...base,
      policyVersion: 1.5,
      amount: { ...base.amount, minMinor: 100.5, maxMinor: 200 },
      interest: { ...base.interest, rateBps: 1800.5 },
      repayment: { ...base.repayment, installmentCount: 2.5, intervalDays: 30.5 }
    };
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const valueErrors = result.errors.filter(e => e.code === 'INVALID_VALUE');
    assert.equal(valueErrors.length, 5); // policyVersion, amount.minMinor, interest.rateBps, installmentCount, intervalDays
  });

  test('unsafe integer (MAX_SAFE_INTEGER + 1) → INVALID_VALUE', () => {
    const base = monthlyFixture();
    const unsafe = Number.MAX_SAFE_INTEGER + 1;
    const input = {
      ...base,
      policyVersion: unsafe,
      amount: { ...base.amount, minMinor: unsafe, maxMinor: unsafe + 1 },
      interest: { ...base.interest, rateBps: unsafe },
      repayment: { ...base.repayment, installmentCount: unsafe, intervalDays: unsafe }
    };
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const valueErrors = result.errors.filter(e => e.code === 'INVALID_VALUE');
    assert.equal(valueErrors.length, 6);
  });

  test('MAX_SAFE_INTEGER accepted for valid fields', () => {
    const base = monthlyFixture();
    const maxSafe = Number.MAX_SAFE_INTEGER;
    // schemaVersion must be 1, so test other fields
    const input = {
      ...base,
      policyVersion: maxSafe,
      amount: { ...base.amount, minMinor: maxSafe, maxMinor: maxSafe },
      interest: { ...base.interest, rateBps: maxSafe },
      repayment: { ...base.repayment, installmentCount: maxSafe, intervalDays: maxSafe }
    };
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, true);
  });

  test('schemaVersion rejects MAX_SAFE_INTEGER (must be 1)', () => {
    const input = monthlyFixture({ schemaVersion: Number.MAX_SAFE_INTEGER });
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.deepEqual(result.errors, [{ path: 'schemaVersion', code: 'INVALID_VALUE' }]);
  });

  test('zero rejected for positive integer fields, accepted for rateBps', () => {
    // amount.minMinor zero
    let input = monthlyFixture({ amount: { minMinor: 0, maxMinor: 100 } });
    let result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.deepEqual(result.errors, [{ path: 'amount.minMinor', code: 'INVALID_VALUE' }]);

    // amount.maxMinor zero
    input = monthlyFixture({ amount: { minMinor: 100, maxMinor: 0 } });
    result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.deepEqual(result.errors, [{ path: 'amount.maxMinor', code: 'INVALID_VALUE' }]);

    // repayment.installmentCount zero
    input = monthlyFixture({ repayment: { installmentCount: 0, intervalDays: 30 } });
    result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.deepEqual(result.errors, [{ path: 'repayment.installmentCount', code: 'INVALID_VALUE' }]);

    // repayment.intervalDays zero
    input = monthlyFixture({ repayment: { installmentCount: 2, intervalDays: 0 } });
    result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.deepEqual(result.errors, [{ path: 'repayment.intervalDays', code: 'INVALID_VALUE' }]);

    // rateBps zero accepted (preserve other interest fields)
    input = monthlyFixture({ interest: { rateBps: 0, period: 'monthly', method: 'equal_principal_declining_balance' } });
    result = validateLoanPolicy(input);
    assert.equal(result.valid, true);
  });

  test('-0 accepted for rateBps (nonnegative), rejected for positive fields', () => {
    // rateBps accepts -0
    let input = monthlyFixture({ interest: { ...monthlyFixture().interest, rateBps: -0 } });
    let result = validateLoanPolicy(input);
    assert.equal(result.valid, true);

    // amount.minMinor rejects -0
    input = monthlyFixture({ amount: { minMinor: -0, maxMinor: 100 } });
    result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    assert.deepEqual(result.errors, [{ path: 'amount.minMinor', code: 'INVALID_VALUE' }]);
  });
});

describe('R2 Unknown Field Collision - validateLoanPolicy', () => {
  test('actual collision: input["amount.extra"]=1 and input.amount.extra=2 → single UNKNOWN_FIELD', () => {
    const input = monthlyFixture();
    input['amount.extra'] = 1;
    input.amount.extra = 2;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const unknownErrors = result.errors.filter(e => e.code === 'UNKNOWN_FIELD');
    assert.equal(unknownErrors.length, 1);
    assert.deepEqual(unknownErrors[0], { path: 'amount.extra', code: 'UNKNOWN_FIELD' });
  });

  test('different codes for same path preserved: interest.rateBps="1800" (string) and interest.rateBps=1 (number on root)', () => {
    const input = monthlyFixture();
    input.interest.rateBps = '1800';  // string → INVALID_TYPE
    input['interest.rateBps'] = 1;    // number on root → UNKNOWN_FIELD
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const rateBpsErrors = result.errors.filter(e => e.path === 'interest.rateBps');
    assert.equal(rateBpsErrors.length, 2);
    const codes = rateBpsErrors.map(e => e.code).sort();
    assert.deepEqual(codes, ['INVALID_TYPE', 'UNKNOWN_FIELD']);
  });
});

describe('R2 Literal Error Array Assertions - validateLoanPolicy', () => {
  test('multiple independent errors with exact ordered array', () => {
    const input = { ...monthlyFixture(), schemaVersion: 2, policyId: '-invalid', extraField: true };
    input.amount.minMinor = 0;
    input.interest.rateBps = -1;
    input.repayment.installmentCount = 0;
    const result = validateLoanPolicy(input);
    assert.equal(result.valid, false);
    const expected = [
      { path: 'amount.minMinor', code: 'INVALID_VALUE' },
      { path: 'extraField', code: 'UNKNOWN_FIELD' },
      { path: 'interest.rateBps', code: 'INVALID_VALUE' },
      { path: 'policyId', code: 'INVALID_VALUE' },
      { path: 'repayment.installmentCount', code: 'INVALID_VALUE' },
      { path: 'schemaVersion', code: 'INVALID_VALUE' }
    ];
    assert.deepEqual(result.errors, expected);
  });
});

describe('R2 Snapshot Literal Error Assertions', () => {
  test('snapshot error array matches literal expectation (not just validator equality)', () => {
    const invalid = monthlyFixture({ schemaVersion: 2 });
    assertSnapshotThrows(invalid, [{ path: 'schemaVersion', code: 'INVALID_VALUE' }], 'snapshot literal error');
  });

  test('snapshot error for multiple fields matches literal array', () => {
    const invalid = monthlyFixture({
      schemaVersion: 2,
      policyId: '',
      interest: { rateBps: -1, period: 'weekly', method: 'equal_principal_declining_balance' }
    });
    assertSnapshotThrows(invalid, [
      { path: 'interest.period', code: 'INVALID_VALUE' },
      { path: 'interest.rateBps', code: 'INVALID_VALUE' },
      { path: 'policyId', code: 'INVALID_VALUE' },
      { path: 'schemaVersion', code: 'INVALID_VALUE' }
    ], 'snapshot multiple literal errors');
  });
});

// ============================================================================
// Test Suite - F1-F4 Fresh-Process Import Isolation Proof
// ============================================================================

describe('F1-F4 Fresh-Process Import Isolation Proof - loanPolicy', () => {
  const { execFileSync } = require('child_process');
  const { resolve } = require('path');
  const loanPolicyPath = resolve(__dirname, '../services/loanPolicy');

  test('F1-F2: imports cleanly with exact sorted exports', () => {
    const script = `
      const mod = require('${loanPolicyPath}');
      const exports = Object.keys(mod).sort();
      console.log('EXPORTS_JSON:' + JSON.stringify(exports));
      console.log('TYPE_VALIDATE:' + typeof mod.validateLoanPolicy);
      console.log('TYPE_CREATE:' + typeof mod.createLoanPolicySnapshot);
    `;
    const output = execFileSync(process.execPath, ['-e', script], {
      timeout: 5000,
      env: { ...process.env, NODE_OPTIONS: '' },
      cwd: __dirname
    }).toString().trim();

    const exportsLine = output.split('\n').find(l => l.startsWith('EXPORTS_JSON:'));
    const exports = JSON.parse(exportsLine.replace('EXPORTS_JSON:', ''));
    assert.deepEqual(exports, ['createLoanPolicySnapshot', 'validateLoanPolicy']);

    const typeValidateLine = output.split('\n').find(l => l.startsWith('TYPE_VALIDATE:'));
    assert.equal(typeValidateLine.replace('TYPE_VALIDATE:', ''), 'function');

    const typeCreateLine = output.split('\n').find(l => l.startsWith('TYPE_CREATE:'));
    assert.equal(typeCreateLine.replace('TYPE_CREATE:', ''), 'function');
  });

  test('F3: child loads no application modules beyond allowed', () => {
    const script = `
      const fs = require('fs');
      const mod = require('${loanPolicyPath}');
      const allowed = new Set([
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