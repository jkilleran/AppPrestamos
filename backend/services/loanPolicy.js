'use strict';

/**
 * Pure loan-policy validation and snapshot module.
 * No imports, no I/O, no side effects, no external dependencies.
 *
 * Version 1 schema:
 * {
 *   schemaVersion: 1,
 *   policyId: string,
 *   policyVersion: positive safe integer,
 *   currency: "DOP",
 *   amount: { minMinor: positive safe integer, maxMinor: positive safe integer },
 *   interest: { rateBps: nonnegative safe integer, period: "monthly" | "annual", method: "equal_principal_declining_balance" },
 *   repayment: { installmentCount: positive safe integer, intervalDays: positive safe integer }
 * }
 *
 * All fields required, no defaults, no coercion, no extra keys.
 */

const POLICY_ID_REGEX = /^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/;
const SUPPORTED_SCHEMA_VERSION = 1;
const SUPPORTED_CURRENCY = 'DOP';
const SUPPORTED_PERIODS = new Set(['monthly', 'annual']);
const SUPPORTED_METHODS = new Set(['equal_principal_declining_balance']);

function isPlainObject(value) {
  if (value === null || typeof value !== 'object') {
    return false;
  }
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

function isSafePositiveInteger(value) {
  return typeof value === 'number' &&
    Number.isSafeInteger(value) &&
    value > 0;
}

function isSafeNonNegativeInteger(value) {
  return typeof value === 'number' &&
    Number.isSafeInteger(value) &&
    value >= 0;
}

function isPlainNumber(value) {
  return typeof value === 'number';
}

function isPlainString(value) {
  return typeof value === 'string';
}

function isBoxedNumber(value) {
  return typeof value === 'object' && value instanceof Number;
}

function validateObject(obj, allowedKeys, prefix, errors) {
  if (!isPlainObject(obj)) {
    errors.push({ path: prefix, code: 'INVALID_TYPE' });
    return false;
  }

  for (const key of Object.keys(obj)) {
    if (!allowedKeys.has(key)) {
      errors.push({ path: prefix === '$' ? key : `${prefix}.${key}`, code: 'UNKNOWN_FIELD' });
    }
  }

  return true;
}

function checkRequired(obj, requiredKeys, prefix, errors) {
  for (const key of requiredKeys) {
    if (!(key in obj) || obj[key] === undefined) {
      errors.push({ path: prefix === '$' ? key : `${prefix}.${key}`, code: 'REQUIRED' });
    }
  }
}

function validateValue(obj, key, typeCheck, valueCheck, prefix, errors) {
  if (key in obj) {
    const val = obj[key];
    if (val === undefined) {
      // Already handled by checkRequired
      return;
    }
    if (!typeCheck(val)) {
      errors.push({ path: prefix === '$' ? key : `${prefix}.${key}`, code: 'INVALID_TYPE' });
    } else if (!valueCheck(val)) {
      errors.push({ path: prefix === '$' ? key : `${prefix}.${key}`, code: 'INVALID_VALUE' });
    }
  }
}

function collectErrors(input, errors, prefix = '$') {
  if (!isPlainObject(input)) {
    errors.push({ path: prefix, code: 'INVALID_TYPE' });
    return;
  }

  const allowedRootKeys = new Set([
    'schemaVersion',
    'policyId',
    'policyVersion',
    'currency',
    'amount',
    'interest',
    'repayment'
  ]);

  validateObject(input, allowedRootKeys, prefix, errors);

  checkRequired(input, ['schemaVersion', 'policyId', 'policyVersion', 'currency', 'amount', 'interest', 'repayment'], prefix, errors);

  // Only validate value if key exists AND is not undefined
  if ('schemaVersion' in input && input.schemaVersion !== undefined) {
    if (!isPlainNumber(input.schemaVersion) || isBoxedNumber(input.schemaVersion)) {
      errors.push({ path: 'schemaVersion', code: 'INVALID_TYPE' });
    } else if (input.schemaVersion !== SUPPORTED_SCHEMA_VERSION) {
      errors.push({ path: 'schemaVersion', code: 'INVALID_VALUE' });
    }
  }

  if ('policyId' in input && input.policyId !== undefined) {
    if (!isPlainString(input.policyId)) {
      errors.push({ path: 'policyId', code: 'INVALID_TYPE' });
    } else if (!POLICY_ID_REGEX.test(input.policyId)) {
      errors.push({ path: 'policyId', code: 'INVALID_VALUE' });
    }
  }

  if ('policyVersion' in input && input.policyVersion !== undefined) {
    validateValue(input, 'policyVersion', isPlainNumber, isSafePositiveInteger, '$', errors);
  }

  if ('currency' in input && input.currency !== undefined) {
    if (!isPlainString(input.currency)) {
      errors.push({ path: 'currency', code: 'INVALID_TYPE' });
    } else if (input.currency !== SUPPORTED_CURRENCY) {
      errors.push({ path: 'currency', code: 'INVALID_VALUE' });
    }
  }

  if ('amount' in input && input.amount !== undefined) {
    if (!validateObject(input.amount, new Set(['minMinor', 'maxMinor']), 'amount', errors)) {
      // amount is not a plain object, errors already added
    } else {
      checkRequired(input.amount, ['minMinor', 'maxMinor'], 'amount', errors);
      validateValue(input.amount, 'minMinor', isPlainNumber, isSafePositiveInteger, 'amount', errors);
      validateValue(input.amount, 'maxMinor', isPlainNumber, isSafePositiveInteger, 'amount', errors);
      if ('minMinor' in input.amount && 'maxMinor' in input.amount &&
          input.amount.minMinor !== undefined && input.amount.maxMinor !== undefined &&
          isPlainNumber(input.amount.minMinor) && isPlainNumber(input.amount.maxMinor) &&
          isSafePositiveInteger(input.amount.minMinor) && isSafePositiveInteger(input.amount.maxMinor)) {
        if (input.amount.minMinor > input.amount.maxMinor) {
          errors.push({ path: 'amount.maxMinor', code: 'INVALID_VALUE' });
        }
      }
    }
  }

  if ('interest' in input && input.interest !== undefined) {
    if (!validateObject(input.interest, new Set(['rateBps', 'period', 'method']), 'interest', errors)) {
      // interest is not a plain object
    } else {
      checkRequired(input.interest, ['rateBps', 'period', 'method'], 'interest', errors);
      validateValue(input.interest, 'rateBps', isPlainNumber, isSafeNonNegativeInteger, 'interest', errors);
      if ('period' in input.interest && input.interest.period !== undefined) {
        if (!isPlainString(input.interest.period)) {
          errors.push({ path: 'interest.period', code: 'INVALID_TYPE' });
        } else if (!SUPPORTED_PERIODS.has(input.interest.period)) {
          errors.push({ path: 'interest.period', code: 'INVALID_VALUE' });
        }
      }
      if ('method' in input.interest && input.interest.method !== undefined) {
        if (!isPlainString(input.interest.method)) {
          errors.push({ path: 'interest.method', code: 'INVALID_TYPE' });
        } else if (!SUPPORTED_METHODS.has(input.interest.method)) {
          errors.push({ path: 'interest.method', code: 'INVALID_VALUE' });
        }
      }
    }
  }

  if ('repayment' in input && input.repayment !== undefined) {
    if (!validateObject(input.repayment, new Set(['installmentCount', 'intervalDays']), 'repayment', errors)) {
      // repayment is not a plain object
    } else {
      checkRequired(input.repayment, ['installmentCount', 'intervalDays'], 'repayment', errors);
      validateValue(input.repayment, 'installmentCount', isPlainNumber, isSafePositiveInteger, 'repayment', errors);
      validateValue(input.repayment, 'intervalDays', isPlainNumber, isSafePositiveInteger, 'repayment', errors);
    }
  }
}

function validateLoanPolicy(input) {
  const errors = [];
  collectErrors(input, errors);

  // Deduplicate by exact (path, code) pair
  const seen = new Set();
  const deduped = [];
  for (const err of errors) {
    const key = `${err.path}|${err.code}`;
    if (!seen.has(key)) {
      seen.add(key);
      deduped.push(err);
    }
  }

  deduped.sort((a, b) => {
    if (a.path < b.path) return -1;
    if (a.path > b.path) return 1;
    if (a.code < b.code) return -1;
    if (a.code > b.code) return 1;
    return 0;
  });
  return errors.length === 0
    ? { valid: true, errors: [] }
    : { valid: false, errors: deduped };
}

function deepFreeze(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }
  Object.freeze(obj);
  for (const key of Object.keys(obj)) {
    deepFreeze(obj[key]);
  }
  return obj;
}

function deepClone(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }
  if (Array.isArray(obj)) {
    return obj.map(deepClone);
  }
  const cloned = {};
  for (const key of Object.keys(obj)) {
    cloned[key] = deepClone(obj[key]);
  }
  return cloned;
}

/**
 * Creates a deterministic snapshot of a validated loan policy.
 *
 * The returned object is deeply frozen via Object.freeze() as in-process
 * protection only; it does not guarantee immutability across realms or
 * when bypassed by direct prototype manipulation. It is NOT immutable
 * database storage, a signed contract, legal validation or configuration
 * activation. For persistent immutability, consumers must serialize
 * (e.g., JSON) before storage or transport.
 *
 * This financial subset does not capture future fees, conditions or rank
 * benefits; those remain outside this module's scope.
 *
 * @param {Object} input - A valid loan policy object
 * @returns {Object} Deeply frozen clone containing only accepted fields
 * @throws {TypeError} With code INVALID_LOAN_POLICY and errors array if input is invalid
 */
function createLoanPolicySnapshot(input) {
  const validation = validateLoanPolicy(input);
  if (!validation.valid) {
    const error = new TypeError('Invalid loan policy');
    error.code = 'INVALID_LOAN_POLICY';
    error.errors = validation.errors;
    throw error;
  }

  const accepted = {
    schemaVersion: input.schemaVersion,
    policyId: input.policyId,
    policyVersion: input.policyVersion,
    currency: input.currency,
    amount: {
      minMinor: input.amount.minMinor,
      maxMinor: input.amount.maxMinor
    },
    interest: {
      rateBps: input.interest.rateBps,
      period: input.interest.period,
      method: input.interest.method
    },
    repayment: {
      installmentCount: input.repayment.installmentCount,
      intervalDays: input.repayment.intervalDays
    }
  };

  return deepFreeze(deepClone(accepted));
}

module.exports = { validateLoanPolicy, createLoanPolicySnapshot };