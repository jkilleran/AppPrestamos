'use strict';

/**
 * Deterministic JSON serialization for loan policy snapshots.
 * Sole local import: ./loanPolicy. No I/O, no side effects, no external dependencies.
 *
 * Serializes a validated loan policy snapshot to a compact JSON string
 * with canonical key order, ensuring deterministic output.
 *
 * The output is project-specific deterministic JSON, NOT a standard
 * cryptographic canonicalization format or a durable/legally immutable
 * contract. This module performs no storage, signing, activation or
 * financial calculation.
 */

const { createLoanPolicySnapshot } = require('./loanPolicy');

/**
 * Serializes a loan policy object to deterministic JSON.
 * Validates the input first via loanPolicy.createLoanPolicySnapshot,
 * then produces a compact JSON string with keys in canonical order.
 *
 * The output is project-specific deterministic JSON, NOT a standard
 * cryptographic canonicalization format or a durable/legally immutable
 * contract. This function performs no storage, signing, activation or
 * financial calculation.
 *
 * @param {Object} input - Loan policy object to serialize
 * @returns {string} Compact JSON string with canonical key order
 * @throws {TypeError} With code INVALID_LOAN_POLICY if input is invalid
 */
function serializeLoanPolicySnapshot(input) {
  // Validate and get frozen snapshot
  const snapshot = createLoanPolicySnapshot(input);

  // Define canonical key order for deterministic output
  const canonicalOrder = [
    'schemaVersion',
    'policyId',
    'policyVersion',
    'currency',
    'amount',
    'interest',
    'repayment'
  ];

  const amountOrder = ['minMinor', 'maxMinor'];
  const interestOrder = ['rateBps', 'period', 'method'];
  const repaymentOrder = ['installmentCount', 'intervalDays'];

  // Build ordered object
  const ordered = {};
  for (const key of canonicalOrder) {
    if (key === 'amount') {
      ordered.amount = {};
      for (const ak of amountOrder) {
        ordered.amount[ak] = snapshot.amount[ak];
      }
    } else if (key === 'interest') {
      ordered.interest = {};
      for (const ik of interestOrder) {
        ordered.interest[ik] = snapshot.interest[ik];
      }
    } else if (key === 'repayment') {
      ordered.repayment = {};
      for (const rk of repaymentOrder) {
        ordered.repayment[rk] = snapshot.repayment[rk];
      }
    } else {
      ordered[key] = snapshot[key];
    }
  }

  // JSON.stringify handles -0 -> 0 automatically
  return JSON.stringify(ordered);
}

module.exports = { serializeLoanPolicySnapshot };