# TASK-XXX — execution and handoff report

Template only; not an active task. Do not put credentials or personal records here.
READ-ONLY for executors. Use its structure in the explicitly approved task report, not by modifying this template.
Shared instructions, task contracts and CURRENT_STATE are maintained only by the user/supervisor.
For LIGHTWEIGHT work, use a concise report with identity/approved plan, the six completion fields from WORKFLOW,
and integrity/handoff evidence; omit irrelevant placeholders. A FORMAL TXT is not required for that route.
Replace this template-only notice with actual task identity in the new report; do not claim the template is the task.

## Identity and authorization

- Task ID/revision:
- Route: FORMAL / LIGHTWEIGHT (TASK-QUICK-...):
- Status:
- Last updated (timestamp/timezone):
- Verified repository / cwd / branch / HEAD:
- Executor / provider / model (if known):
- User-approved plan and scope (reference, no invented approval):
- LIGHTWEIGHT request and approved plan (exact files, acceptance criteria, checks, effects and report path):
- Approval pending after handoff or scope change:

## Files changed

- Absolute paths and purpose:
- Preexisting changes preserved:
- Comparison against pre-task state:
- Protected-file hashes/path inventory comparison (including untracked files and parent AGENTS):
- Unexpected changes or new instruction files detected:
- Incomplete edits or overlapping changes:

## Implementation summary

- Behavior implemented:
- Contracts preserved:
- Relevant decisions and evidence:
- Corrected test assertions, if any: old expectation -> new expectation, exact contract ID, coverage preserved:

## Contract coverage

FORMAL: map every acceptance criterion, including non-code checks. LIGHTWEIGHT: concise mapped bullets suffice.
Preserve task-authored expected outcomes; mark evidence pending until actually checked. Do not derive the
only expected result from the implementation under test. Uncovered criteria must remain explicit.

| Requirement ID | Input / scenario | Contract expectation | Test name / check | Actual result / evidence |
| --- | --- | --- | --- | --- |

## Tests and commands

| Phase / timestamp | Cwd | Command | Exit code / completion | Passed / failed / skipped | Actual result |
| --- | --- | --- | --- | --- | --- |

- BASELINE captured before edits, or unavailable with explanation (never fabricate historical results):
- REGRESSION RED: tests-only reproduction before production fix, or not applicable/unavailable with reason:
- FINAL: checks against completed implementation, without reusing baseline evidence:
- Baseline versus final failing test names/files and assertion/error signatures; new or changed failures:
- Explanation for changed counts and any modified/skipped assertions:
- Not run / timed out / partial checks and why:
- Browser/device checks (who, when, relevant version):
- Runtime changes / observed PIDs and URLs, only if relevant:
- QA writes / indirect effects / private artifact reference, without PII:
- Backup verification if needed (do not include secrets or sensitive location details):

## Blockers or deviations

- Unmet acceptance criteria:
- Attempts/hypotheses and results:
- User decisions needed:
- Exact next authorized action:
- Proposed shared documentation/context corrections for the supervisor (NOT applied by executor):

## Final result

READY_FOR_REVIEW / BLOCKED / PAUSED

## Independent review and user acceptance

Executor must leave this section unclaimed. Reviewer/user update it when actually requested/performed.

- Technical review: not requested / pending / VERIFIED / NEEDS_CORRECTION
- Reviewer findings and supporting checks:
- Physical/user-flow validation: pending / user-confirmed, with date/scope
- User acceptance: pending / ACCEPTED, with explicit request/reference
