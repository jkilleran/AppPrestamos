# Multi-model development workflow

User-approved agreement: 2026-09-20. Read the repository AGENTS.md first.
This workflow applies to every model/provider, including small local models. Capability changes task sizing,
not permissions or quality requirements. The user owns product decisions and acceptance.

## Roles and acceptance

1. **Planner/reviewer (this conversation):** inspect enough architecture to define a coherent task,
   dependencies, exact interfaces, risks, prohibited changes and observable acceptance criteria.
   For FORMAL work, deliver only ONE executable English `.txt` task. LIGHTWEIGHT requests do not require
   a visit to this conversation or a planner-authored TXT. Do not implement app code unless explicitly requested.
2. **User:** selects an executor, approves its plan, tries relevant flows and accepts or requests correction.
3. **Executor (OpenCode):** inspect the request/task's current inputs, propose a short plan, wait for user approval,
   then implement, test, debug, and report. It cannot accept its own work on the user's behalf.
4. **Reviewer:** when requested by the user, compare the actual diff and evidence to the acceptance criteria.
   Reproduce relevant checks where safe. Do not trust “all tests passed” without commands, results and scope.
   Report defects/missing evidence before preparing another task.

No task is accepted solely because the worker finishes, the code compiles, or a page loads.
Technical verification and the user's practical acceptance are distinct. Physical iPhone validation may
remain pending even when server-side checks pass. The reviewer does not silently implement corrections.

## Two routes — natural-language intake

The user may describe the desired outcome briefly, in Spanish or English. The executor is responsible for
finding the relevant code and turning that request into a bounded, verifiable plan. Do not demand file paths,
technical specifications or a supervisor-written task when the request qualifies for LIGHTWEIGHT work.
Read the required shared guidance once per session and refresh it after changes/handoff; inspect only relevant source.

### LIGHTWEIGHT — direct small changes

Use this route when inspection shows one clear, local, low-risk change: for example, a button color, spacing,
an icon or non-contractual UI copy. A small isolated bug fix can qualify if its expected behavior is clear
and it changes no sensitive/shared contract. Classify by actual impact, not line count, filename or prompt length:
a cosmetic login-button change is not an authentication change, but changing what that button authorizes is.

1. Locate the actual target and check its consumers. Do not change a global theme/shared widget for a
   one-page request without identifying the wider impact. A purely local override may preserve the intended scope.
2. Ask only about ambiguity that materially changes the result. Resolve technical details from the code;
   state safe assumptions in the plan (e.g. reuse the existing green token), not invented product decisions.
3. Propose a short English plan in chat using the outline below, with real paths and checks; wait for approval.
   The request plus that approved plan is the contract. No separate TXT or nine-section task is required.
4. After approval, capture the baseline/integrity inventory and start the compact report with the approved plan.
   Implement, verify and update that report with results or interruption state. Do not create the report or modify
   any file before approval. No unrelated improvements or automatic next task.

```text
Mode / ID: LIGHTWEIGHT / TASK-QUICK-<YYYYMMDD>-<unique-short-slug>
Objective and acceptance: <observable result; important behavior that must stay unchanged>
Files: <exact source/test paths>; report: tasks/<same-ID>-report.md
Plan: <brief steps, local/shared impact and assumptions>
Verification: <scoped commands and visual/interaction checks; any unavailable check>
Effects: <data/runtime effects, normally none; explicitly flag any requested runtime operation>
Approval: Awaiting your approval; no edits performed.
```

Check that the proposed ID/report path is unused; do not overwrite another report or reuse a FORMAL task ID.
The user need not invent IDs, filenames or acceptance tests. Approval covers the listed files, criteria and report.
Preserve the approved plan and approval reference in that report so another model can resume without the old chat.
This is a record of authorization, not permission to revise the contract inside the report. Scope changes need new approval.
Use the same six completion fields below, briefly, plus identity/approved plan and integrity evidence in the saved report.
Irrelevant report fields may be omitted; required evidence must not be replaced with an unsupported “all passed”.
Independent supervisor review remains available when requested; the lightweight route does not require returning here
for every small change. Only the user accepts the result; never claim an independent VERIFIED review that did not happen.

### FORMAL — planned, detailed work

Use a supervisor-authored English TXT with the full task template for complex, uncertain or cross-component work,
including financial formulas/units/terms, eligibility, approvals, payments, signatures, authentication/authorization,
API contracts, persistent data/schema changes, dependencies, infrastructure or broad refactors/shared UI changes.
Shared governance remains supervisor-owned; FORMAL classification does not authorize an executor to edit it.
Do not silently downgrade an already selected FORMAL contract or relax its criteria because implementation looks easy.

If a LIGHTWEIGHT request exposes these risks, stop before expanding work, explain the impact and request a FORMAL
task from the supervisor. If discovered after edits, preserve/report the partial state without broad rollback;
do not continue outside the approved scope. Ordinary scoped debugging is allowed; a scope change is not.

### Common rules and task switching

Both routes keep the same approval, protected-file integrity, Git, data, runtime, retry and acceptance rules below.
Only one implementation task and one editing executor may be active. An unfinished task is not silently accepted,
discarded or superseded by a new request. Ask for an explicit pause/switch when needed, retain its status/evidence,
and stop the prior executor before starting the newly approved work. Do not change CURRENT_STATE yourself.
An intentional switch is allowed without falsely marking the earlier task accepted; the user/supervisor records it.
RUN/STOP/RESTART keep their separate operational exception; quoted examples in this guide are not execution requests.

## Task lifecycle

`DRAFT → AWAITING_EXECUTOR_APPROVAL → IN_PROGRESS → READY_FOR_REVIEW → VERIFIED → ACCEPTED`

This is the independently reviewed path. For LIGHTWEIGHT work when no independent review is requested,
the user may explicitly accept from READY_FOR_REVIEW after checking the result/evidence; keep independent
review marked not requested, never invent VERIFIED. This does not turn failed criteria into passing checks.

- `DRAFT`: proposed FORMAL contract or LIGHTWEIGHT plan; not permission to modify the app.
- `AWAITING_EXECUTOR_APPROVAL`: executor presented its own plan; waits for explicit user approval.
- `IN_PROGRESS`: approval applies to the named task, revision, plan and bounded data targets.
- `READY_FOR_REVIEW`: worker claims implementation done and provides evidence; not a final acceptance.
- `VERIFIED`: requested technical review supports the criteria; record any device checks still pending.
- `ACCEPTED`: user explicitly accepts the result. Only then may a requested next task proceed normally;
  an explicit pause/switch may leave earlier work unresolved, never implicitly accepted.
- `BLOCKED`: genuine missing dependency/decision, or two correction attempts without progress.
- `NEEDS_CORRECTION`: review found a defect or missing evidence; continue the same objective with a focused correction.
- `PAUSED`: user pauses or hands off; preserve state and do not continue silently.

Use CURRENT_STATE, the latest explicit user selection/approval and the task report to identify active work;
not filenames or old conversation claims. A `.txt` file existing in the repo does not activate it.
LIGHTWEIGHT work may be selected directly in OpenCode before the supervisor updates CURRENT_STATE. Record that
explicit selection/approval in its report and propose the context update; do not require a TXT to proceed.
An unexplained conflict with another active task still requires clarification, not silent replacement.
Do not resurrect historical TASK-001/TASK-001-A or reuse their identifiers for new work.
Corrections can use a clearly related revision/suffix; do not expose a large backlog of future tasks.

## Executor approval gate

Before editing, installing anything, starting the app, running a mutating test, or changing persistent state:

1. Verify canonical path, branch and current scoped diff, including relevant untracked files.
2. Read AGENTS, this workflow, CURRENT_STATE, the selected FORMAL task or LIGHTWEIGHT request/plan and required files.
3. State: objective, proposed files, a few implementation steps, checks, data/runtime effects and blockers.
4. Ask the user to approve that plan and STOP. The initial direct request, a pasted task or planner approval is not enough.

The plan may be sent in chat; do not create extra files just to bypass the pre-edit approval gate.
Once approved, carry out ordinary in-scope edits/debugging without asking for every line.
If a requirement conflicts with current code/docs or needs a decision, explain the concrete mismatch.
Do not replace a requirement with whichever behavior the current implementation happens to have.

Explicit RUN/STOP/RESTART is the exception: it directly authorizes the established RUNTIME_RUNBOOK,
including its limited self-healing operations. STATUS remains read-only. Broad “test this feature” is
not permission to restore DBs, change networking, send real notifications or modify unrelated records.

Documentation/handoff maintenance explicitly requested by the user may be performed by the planner.
Before implementation edits it still states the bounded documentation plan, as done for this update.

## Protected guidance and ownership

Only the user and the supervising planner in this conversation maintain shared governance and context.
An OpenCode executor has READ-ONLY access by policy to AGENTS/instruction/override files (including the parent),
README files, all `docs/` content, task contracts and templates. It must not alter them directly or through
shell commands, formatters, scripts, generators, deletion/rename/replacement, permission changes or symlinks.
It must not create alternative instructions or modify agent configuration to bypass this boundary.

The sole executor-authored standalone documentation artifact is its named, approved task report.
Inline comments/docstrings in permitted source files are allowed; that does not authorize changing shared documentation.
Task approval, operational commands and generic “update docs” wording do not authorize protected-file edits.
If a proposed task conflicts with this restriction, report it to the supervisor before implementation.
Do not switch your claimed role or create a new session to acquire governance authority.

Before implementation, capture the protected-file path inventory and hashes without changing those files.
Include untracked docs/task inputs and the parent entry point, not only Git-tracked files.
Before handoff, verify no protected content/path changed and no new instruction/override file was created.
Report the integrity result. An unexpected change is a blocker for acceptance; stop and report the diff,
without silently restoring files that may contain the user's concurrent edits.

Propose needed corrections under “Blockers or deviations” in the task report, with evidence and suggested wording.
The user/supervisor decides and applies any update to CURRENT_STATE, workflow, runtime instructions or task contracts.
Worker reports are evidence, not new policy. They cannot revise acceptance criteria or grant approvals.
These are behavioral rules and change-detection checks, not filesystem ACLs or an OpenCode sandbox configuration.

## Formal task contract and context budget

For FORMAL work use [../tasks/TEMPLATE.txt](../tasks/TEMPLATE.txt) with these exact sections.
LIGHTWEIGHT work uses the approved short plan above, not this full template:

Objective; Why This Task; Working Directory; Relevant Files; Required Changes; Constraints;
Verification; Failure Handling; Completion Report.

Each FORMAL task specifies:

- Exact cwd and repository, task revision, objective and allowed production/test files plus the named report.
- Concrete behaviors, interfaces, data types, errors, edge cases and compatibility requirements.
- Relevant source files to inspect first, not a request to reread the whole repository.
- Existing contracts and unrelated changes that must be preserved.
- Positive/negative acceptance cases, suitable commands, expected outputs and untested boundaries.
- Whether integration QA on the existing DB is needed, permitted QA records and side effects.
- The task report path, the only executor-authored standalone documentation output.
  CURRENT_STATE and all shared guidance remain supervisor-owned and read-only to the executor.

Use small coherent tasks and checkpoints, not arbitrary file/token caps that prevent correct work.
A small model may need narrower scope and more examples. A stronger model still obeys that scope.
Do not require a chain-of-thought transcript; request a short actionable plan and verifiable evidence.
Use `rg`/`rg --files` when available, otherwise `grep`/`find`; missing search tools do not justify installing toolchains.
Do not inspect node_modules, generated builds, dumps or old archives for general context.

## Shared checkout, Git and safe recovery

One editing executor at a time. Finish or pause the old executor before switching providers/models.
Do not silently spawn another implementing agent, open an alternate checkout, or run competing worker sessions.
If another process changes an owned file, stop overlapping work and ask the user how to reconcile it.

Before editing, capture relevant pre-task content/diffs or private temporary snapshots; inspect untracked files too.
Compare final changes against that pre-task state, NOT solely against HEAD. Never absorb other work into the task.
Revert only proven task-owned changes when requested/needed and safely separable; no wholesale reset/restore.
If ownership cannot be separated, report the conflict rather than overwriting.

Commit requires an explicit request even after acceptance. Push requires separate explicit authorization.
When authorized, review/stage only scoped source/docs; never automatically `git add -A`.
Never commit secrets, DB backups, node_modules, generated output, uploaded private files or `.DS_Store`.
Do not create a branch/worktree/clone by default; ask if isolation is truly necessary.

## QA on the existing local database

The user explicitly chose the existing local DB and existing accounts. Do not provision another DB/login per test.
Mocked unit tests remain useful and preferred for edge cases; this does not replace requested real-flow QA.

For integration QA, the approved plan must specify:

- The verified local DB target (name/host only in reports, never credentials).
- Existing account roles to reuse. If login access or the required role is unavailable, ask securely;
  do not guess passwords, reset credentials or create users. Do not request passwords in versioned files.
- New test records and a recognizable marker, such as `QA:<task-id>:<run-id>` in an existing appropriate free-text field.
  Do not change schema to add a marker. If no suitable field exists, use a private record-ID manifest.
- Expected writes, indirect effects, necessary checks and whether cleanup is authorized.

Specific permission is required before modifying preexisting loans, payments, documents or account data.
Creating a QA loan and approving it can affect an existing user's category/counters; those indirect effects
must be explicitly disclosed and authorized too. Use mocks/read-only checks until that permission exists.
Do not casually use a user's existing financial records as fixtures.

Newly created QA records may be exercised within the approved test scenario. Preserve existing data.
Do not delete test records, reset counters or restore a dump as automatic cleanup; request exact cleanup scope.
Record new IDs and effects in a private local artifact; shared reports use counts/redacted references, no PII.
Keep financial/approval/signature decisions out of generic guidance: ask for product requirements when needed.

### Backups

The user reports an existing backup and authorizes a fresh private local backup when needed before consequential writes.
Do not assume its age, contents, location or restorability. Verify metadata without displaying personal records.

Before creating one: resolve the exact intended local DB; use an approved private local directory outside the repo,
avoid cloud-synced/public locations, use restrictive directory/file permissions, a unique non-overwriting name,
and existing compatible PostgreSQL tooling. Do not print connection secrets in commands/reports.
If a safe location/tool is unavailable, stop data-changing QA and request what is missing; keep safe work moving.

Verify command success, nonzero file size and readable archive metadata (`pg_restore --list` for custom format).
Do not claim a restore was tested merely because the dump lists. Do not create another DB for a restore test,
overwrite existing backups or automatically delete old backups. Creating a backup never authorizes restoration.
No backup is required for a documentation-only task or purely mocked tests.

### Outbound services and privacy

QA is local. No real email, push, cloud storage, deployment, or remote DB access without explicit approval.
Check/mimic the actual send paths: disabling the outbox alone does not disable direct SMTP calls.
Some GET endpoints have side effects, e.g. `/test-email`; HTTP method alone does not prove read-only behavior.
Importing backend modules may connect to DB; launching `index.js` performs existing schema/data tuning.
Do not do either as a casual syntax check. Use `node --check` and mocks instead.
Never include credentials, tokens, rows, signatures, documents or unredacted screenshots in handoffs.

## Verification, not just a green claim

Tests must verify the agreed behavior, not mirror an implementation bug.
Add regression/negative tests where applicable. Diagnose real failures; do not delete tests, weaken assertions,
skip cases, or relabel failures merely to get green results. Correct an objectively broken harness with evidence.
Separate a preexisting failure from a regression; neither can be called a passing suite.

### Contract-first checks and trustworthy evidence

Apply these controls proportionally. LIGHTWEIGHT work can use a few acceptance/check bullets in its approved
plan and short report. FORMAL work uses requirement IDs and the matrix below; do not demand a lengthy matrix
for a cosmetic change. The same no-fabrication and no-test-weakening rules apply to both routes.

1. Before production edits, derive expected outcomes from the approved request/contract. The planner includes
   mandatory concrete examples for ambiguous/high-risk behavior. The executor maps each criterion to a planned
   test or explicit manual/source check; show the mapping in its preapproval plan and, after approval, its report.
   Do not create a separate executor-owned specification or edit shared templates/instructions.

   | Requirement ID | Input / scenario | Expected result from contract | Test name / check | Actual result / evidence |
   | --- | --- | --- | --- | --- |
   | <ID> | <including relevant edge state> | <literal result or observable invariant> | <named check> | <pending until run> |

2. Mandatory examples and expected outcomes are read-only contract requirements for the executor. Do not
   weaken, omit or replace them to fit current code. Additional tests are welcome within scope. On ambiguity
   or contradiction, ask the supervisor instead of selecting whichever interpretation makes tests pass.
   Do not use the function under test to compute its own expected answer, or compare two implementations that
   share the same bug as the only oracle. Literal fixtures/expected errors and independently derived invariants
   must anchor the test; cross-function consistency checks are useful additions, not substitutes.

3. For a bug fix, after approval capture the original baseline, add/correct a focused regression test, and
   demonstrate the intended assertion failing against unchanged production code before fixing it when feasible.
   Record this tests-only RED phase separately, then rerun after the fix. A syntax/import/fixture failure is
   not evidence of the reported behavioral bug. If it no longer reproduces or cannot be tested safely, report
   why and the actual evidence; do not fabricate a red run or deliberately break production to manufacture one.

4. Existing tests are evidence, not higher authority than the contract. An objectively wrong assertion may
   be corrected only within the approved files/scope, with the old expectation, new expectation and precise
   requirement recorded. Preserve or strengthen coverage; never delete/skip the scenario to make it pass.
   An unapproved change to intended behavior requires a new decision, not a test rewrite.

5. For validation contracts, distinguish absent fields, explicit undefined, null, wrong primitive/boxed types,
   valid-type invalid values, boundary values and valid values. Cover each specified field/object level, parent
   error short-circuiting, output order/uniqueness and input preservation where required. These are test-design
   prompts, NOT a global mandate to change every API's behavior or error vocabulary. For the loan-policy
   contract specifically: absent/undefined field -> REQUIRED; null/wrong type -> INVALID_TYPE;
   right type but invalid value -> INVALID_VALUE; identical path/code pairs appear once.
   Check numerical boundaries both just outside and at accepted limits. Count assertions/scenarios honestly.

6. A check must exercise what its name claims. A "fresh import" needs a new process or otherwise proven isolated
   loading, not an already cached require. A real interaction is not proven by a screenshot; no-side-effects
   and protected-file claims need scoped inspection/integrity evidence, not just naming a test accordingly.
   State what each check cannot establish, including actual device, DB, integration or legal behavior.

7. Keep BASELINE (before edits), REGRESSION RED (tests-only change) and FINAL runs distinguishable: timestamp,
   cwd, command, exit/completion status, counts where available and concise output/failure evidence. Do not copy
   one run into another phase or infer current results from historical reports. If the baseline was not captured,
   say unavailable; do not reset the dirty tree or reconstruct fictional historical evidence.
   Compare failing test names/files and assertion/error signatures, not just total failure counts. Different
   failures with equal counts may be regressions. Explain count changes caused by added/restructured tests.
   Sandbox/permission/tooling failures are not automatically product defects or passing checks; request the
   required tool approval or report the limitation without bypassing it.

Before handoff, complete the matrix with actual evidence for every criterion, including non-code requirements
such as comments and import isolation. Mark uncovered/unavailable criteria pending, not satisfied. Review the
diff for changes to assertions, skips and fixtures; justify each contract-driven correction. READY_FOR_REVIEW
is not ACCEPTED, and passing tests do not waive known unmet criteria. Independent requested review uses its own
contract-derived examples, not only a rerun of the worker's tests. Never assert "all requirements met" from counts alone.

### Proportionate checks by scope

Derive observable acceptance criteria from the request before editing and test against those criteria,
not against whatever the implementation returns. Do not change expected results merely to make a test pass.
For LIGHTWEIGHT work, select checks proportional to the actual impact: changed-file formatting/static checks,
relevant existing tests and a focused visual/interaction check for UI where available. Add a regression test
when behavior changes and automated coverage is practical. Do not run unrelated financial suites just for a
local color change. Explain omitted/unavailable checks; a screenshot alone does not prove interaction behavior.
Check contrast/readability and affected enabled/disabled states for visual controls, preserving their actions.
If the app is not running or UI tooling is unavailable, report pending visual validation rather than silently
starting/reconfiguring services. An explicitly requested runtime operation must follow the runbook.
For FORMAL work, the selected contract determines required suites; this proportional rule does not waive them.

Commands by scope (run from the indicated directory):

```bash
# backend/
node --check path/to/changed-file.js
node --test test/relevant.test.js
npm run check
npm test

# software1/
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
# When the affected scope needs browser compatibility:
flutter test --platform chrome
```

Use actual file names, not literal placeholders. No tests need a fixed historical count.
`npm run check` uses `find -exec`, so inspect its output and directly check each changed JS file.
For shared contracts, test both consumers. For changed UI flows, verify the actual interaction where feasible.
Native permissions/plugins and physical Safari may need separate user validation; document the boundary.
For docs-only tasks, check links, paths, preserved rules, template sections and diff whitespace; do not start the app.
Before an explicitly requested code commit, run the relevant full checks and inspect scoped diffs/status.

Record each command's cwd, exit code, concise result and passed/failed/skipped counts where applicable.
Never report a timeout, partial output, unexecuted command, screenshot, or historical run as a passing test.
When blocked, report the exact unmet acceptance criterion. Do not change runtime/model limits to hide failures.

## Retry, interruption and model handoff

After the same failure survives two correction attempts with no measurable progress, stop and report BLOCKED.
Show the symptom, two distinct hypotheses/actions, results and the smallest decision or missing dependency needed.
This is not a cap of two tests overall; legitimate measured progress may continue inside the approved scope.
Do not repeat the same failing edit against stale text. Re-read its current source and make a minimal correction.

Transport/decode error or interrupted output does not prove an action failed. Inspect file contents, processes,
test outputs and known record IDs before resuming. Never blindly repeat an insert, approval, payment or other
non-idempotent write. If its result cannot be determined safely, stop and ask.
Do not auto-restart worker sessions, alter model/provider settings or extend retry limits without explicit permission.

Before handoff, the executor updates ONLY its approved task report with:

- Task ID/revision, state, canonical cwd/branch/HEAD and executor/model if known (never guess).
- Approved scope and whether a new plan approval is pending; never fabricate an approval.
- Preexisting changes, task-owned changes, unfinished edits and preserved contracts.
- Checks actually executed, results/counts, commands still needed and device verification status.
- Runtime changes if any, observed PIDs/URLs with timestamps (not perpetual claims), QA effects and private artifact references.
- Blockers, product decisions, failed approaches and the exact next authorized step.
- Protected-file integrity check and proposed shared-context corrections, without applying them.

The supervisor reviews the report and maintains CURRENT_STATE; the executor never edits that shared file.
If a report differs from CURRENT_STATE only because it records a newer explicit user selection/approval under
the intake/switch rules, preserve both and flag the context update for the supervisor; do not block that authorized
work solely on documentation lag. If authorization/scope is uncertain or contradictory, stop and seek direction.
The successor reads those records and the selected files, verifies current state, then presents its own plan
and waits for the user's approval. Do not replay completed work merely because a chat was compacted.
Persistent files are the shared context; no model is assumed to remember another provider's session.

## Worker completion report

Return only the following structured fields in English, with enough evidence to reproduce the checks:

1. Files changed (absolute paths; production/test/documentation; verified root/branch).
2. Implementation summary (what behavior changed and what was deliberately preserved).
3. Tests/commands executed (cwd, exit codes, concise outputs, elapsed time if relevant).
4. Test counts (passed/failed/skipped; incomplete and not-run suites separately).
5. Blockers or deviations (data/runtime effects, pending device checks, no-progress retries, approval changes).
6. Final result: `READY_FOR_REVIEW` or `BLOCKED` (or `PAUSED` when the user paused it).

Update only the approved report file with the same evidence; include the protected-file integrity result.
Include criterion coverage, baseline/RED/final distinctions, identified baseline failures and any justified
assertion changes in the existing fields. Use the full matrix for FORMAL work and short mapped bullets for LIGHTWEIGHT.
For LIGHTWEIGHT work, a concise report is sufficient; preserve the request/approved plan, identity, approval reference,
checks, pending validation and next authorized step. No full TXT contract is required for handoff.
Do not edit shared context, templates or instructions. No claim of ACCEPTED from the worker.
The reviewer reports findings by importance and unmet criteria before recommending acceptance or a correction.
