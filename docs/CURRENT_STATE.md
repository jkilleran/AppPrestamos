# AppPrestamos — current state and model handoff

Last updated: 2026-09-27. Read ../AGENTS.md first. Keep this file concise and evidence-based.
This is shared continuity for the planner conversation and OpenCode executors, not permission to resume old tasks.
Do not record secrets, personal rows, private document contents or passwords.
READ-ONLY for OpenCode executors. Only the user/supervising planner updates this shared context after reviewing evidence.
Executors put handoff details and proposed corrections in their own approved task report, never in this file.

## 2026-09-27 operational and orchestration update

- OpenCode Remote now has an explicit, independently scoped RUN/STATUS/STOP procedure in AGENTS.md and
  RUNTIME_RUNBOOK.md. Its verified topology is the persistent loopback service at `127.0.0.1:49374`, exposed only
  to the tailnet at `https://johans-macbook-pro.tailfbc2ea.ts.net`; AppPrestamos RUN/STOP remains separate.
- Paperclip is under consideration as an orchestration layer, with a possible Codex/Astra planner and OpenCode workers.
  It is not installed or authorized to run yet. Preserve the existing one-task, plan-approval, evidence-review,
  no-commit/no-push and governance-ownership controls during any future pilot.

## Start here after a model/provider/reasoning-level change

1. Read AGENTS.md, WORKFLOW.md and this file. Identify the user's latest request.
2. Verify canonical cwd, Git root and branch; inspect the relevant current files/diff.
3. Read the explicitly selected FORMAL task or LIGHTWEIGHT request/approved plan and its report if present.
   A direct new request does not need a TXT; use WORKFLOW's intake/switch rules. Without a current request, do not pick old work.
4. Preserve role boundaries: this conversation plans/reviews; OpenCode implements after presenting its own plan
   and obtaining user approval. A model switch does not change authority or waive that approval.
5. Treat old chat summaries and historical documents as leads to verify, not current source truth.

These files reduce dependence on chat history. They do not guarantee identical performance across models/effort levels,
rewrite a model's internal memory, or prove that an existing session automatically reloaded changed instructions.
When continuing an existing session, explicitly read the current files. If the tool does not discover AGENTS automatically,
include its path and the selected task in the handoff prompt. Verify that the executor can state the key constraints.

## Agreed working arrangement

- User communication: Spanish. Task contracts and structured worker reports: English.
- Two routes: LIGHTWEIGHT direct requests in OpenCode with a short approved English plan; FORMAL supervisor-written TXT
  for complex/sensitive/shared-contract work. Classify by actual impact and escalate scope; see WORKFLOW for details.
- Planner here: architecture/context analysis, one precise FORMAL task at a time, requested independent review.
  No app implementation unless the user explicitly asks. Requested documentation maintenance is allowed.
- OpenCode executor: read request/task and current files → short plan → wait for user approval → implement/test/debug → report.
  LIGHTWEIGHT work needs no supervisor TXT; preserve the approved request/plan in its own approved TASK-QUICK-* report.
- One editing executor and one active task. User switches between providers/models sequentially.
- Worker result is READY_FOR_REVIEW, not ACCEPTED. User practical testing and requested technical review are distinct.
- No automatic next task. Normal progression requires acceptance and user request; an explicit pause/switch may
  leave earlier work unresolved, never implicitly completed. Keep one editing executor and preserve its handoff.
- No automatic commits or push. Commit and push require separate explicit authorization.
- Preserve current stable local working tree; do not restore the old commit or copy obsolete checkouts over it.
- RUN/STOP/RESTART directly authorize the known runbook. STATUS is read-only; no extra operational approval gate.
- Stop after two correction attempts on the same failure without measurable progress; preserve a reproducible handoff.
- Governance ownership: user/supervisor only. Executors must not edit AGENTS/instruction/override files,
  README files, docs/, task contracts, templates or agent configuration to change the workflow.
  Their only standalone documentation output is their own explicitly approved task report.
  Hash/path comparisons detect unexpected protected-file changes; no OS-level write lock has been configured.

## Active work

- Current request (2026-09-21): correct TASK-004-A's insufficient test evidence before continuing the prepared queue.
  Execute only one contract at a time: executor plan → user approval → implementation/report → review/acceptance.
  Preparing this queue does not authorize concurrent work or automatic continuation.
- [TASK-004-A](../tasks/TASK-004-A.txt) plus its correction [TASK-004-A1](../tasks/TASK-004-A1.txt) are
  technically `VERIFIED`, pending explicit user acceptance. A1 repaired only the test evidence: call-recording arrays,
  zero/one-call assertions, normalized create/update arguments, equivalent invalid-update families and response bodies.
  Independent review on 2026-09-21 passed syntax and 122/122 focused tests; the full backend suite, with local-listen
  permission, passed 412/417 and retained exactly the same five known `loan-request-create.test.js` failures.
  No production file was changed by A1. Its report is `tasks/TASK-004-A1-report.md`.
- Prepared execution order after TASK-004-A acceptance:
  1. [TASK-004-B](../tasks/TASK-004-B.txt) — repair only the broken loan-request test harness flags.
  2. [TASK-004-C](../tasks/TASK-004-C.txt) — validate option IDs and add 404/generic-500 mutation semantics.
  3. [TASK-004-D](../tasks/TASK-004-D.txt) — test the actual HTTP router/auth/controller composition in memory.
  4. [TASK-004-E](../tasks/TASK-004-E.txt) — align Flutter admin form validation/error feedback with the API.
- [TASK-004-B](../tasks/TASK-004-B.txt) is technically `VERIFIED`, pending explicit user acceptance. Its test-only
  repair made the three mock-control flags effective, reset them between cases, and corrected setup values so the
  intended category/income/insert branches are reached. Independent review passed syntax, 18/18 focused tests and
  417/417 full backend tests with local-listen permission; no production file was changed by B. Report:
  `tasks/TASK-004-B-report.md`.
- [TASK-004-C](../tasks/TASK-004-C.txt) and corrections [TASK-004-C1](../tasks/TASK-004-C1.txt) /
  [TASK-004-C2](../tasks/TASK-004-C2.txt) are technically `VERIFIED`, pending explicit user acceptance. C1 added
  actual-model mocked-pool coverage and corrected the scope/RED record; C2 replaced its cache false positive with
  direct same-process identity/absence assertions and guaranteed cleanup. Independent final runs passed 5/5 model,
  176/176 combined loan-option and 471/471 full backend tests with local-listen permission. Reports: C, C1 and C2.
- Selected correction: [TASK-004-C1](../tasks/TASK-004-C1.txt), revision 1 / DRAFT. It may add only
  `backend/test/loan-option-model.test.js` and its own `tasks/TASK-004-C1-report.md`; production, existing tests and
  prior reports are read-only. The user's 2026-09-21 instruction to continue authorizes preservation of exactly the
  four existing numeric-ID expectation changes in `loan-option-validation.test.js`, not further edits. C1 must add
  durable mocked-pool coverage of the actual delete model and accurately classify C's historical RED as harness failure.
- [TASK-004-D](../tasks/TASK-004-D.txt) is `NEEDS_CORRECTION`, not accepted. Its 18 HTTP behavior tests pass, but D8
  does not restore all application modules loaded under the test JWT secret/mocks: `authConfig`, `auth.middleware`,
  `loan_option.controller` and `loan_option.routes` remain cached. Separate-process combined/full runs cannot prove
  same-process cleanup. Do not start TASK-004-E until a focused correction restores and directly verifies the exact
  pre-test cache presence/object identity for every affected application module.
- Selected correction: [TASK-004-D1](../tasks/TASK-004-D1.txt), revision 1 / DRAFT. It may modify only
  `backend/test/loan-option-routes.test.js` and create `tasks/TASK-004-D1-report.md`. It must capture, freshly load,
  restore and directly assert the same-process environment/cache state for all seven affected application boundaries,
  while preserving the existing 18 HTTP cases. The executor must still present its plan and wait for user approval.
- TASK-004-D1 is `NEEDS_CORRECTION` after independent review. Its focused suite passes 19/19, but it preloads
  `authConfig` and `auth.middleware` before recording `originalCache`; consequently, its "originally present" state is
  task-created rather than the true process-entry state, and teardown may leave those modules cached when they were
  initially absent. A follow-up must capture the authentic seven-path baseline first and test the generic present-case
  restoration separately without redefining that baseline. TASK-004-E remains blocked pending this correction.
- Selected follow-up: [TASK-004-D2](../tasks/TASK-004-D2.txt), revision 1 / DRAFT. It may modify only the existing
  route test and create its D2 report. It separates the immutable authentic process-entry snapshot from synthetic
  helper branch coverage, then directly verifies authentic teardown/idempotence. Executor plan approval is still
  required; do not start TASK-004-E.
- TASK-004-D plus corrections D1/D2 are now technically `VERIFIED`, pending explicit user acceptance. D2 removed the
  manufactured pre-capture auth preload, captures/freeze-restores the authentic seven-path baseline, and tests generic
  present/absent restoration with isolated synthetic cache objects. Independent review passed syntax, 21/21 focused,
  197/197 combined loan-option and 492/492 full backend tests. No production, data or runtime state changed. TASK-004-E
  is the next available contract but is not started or automatically authorized.
- The user requested a more demanding, less prescriptive combined frontend task. [TASK-005-A](../tasks/TASK-005-A.txt)
  revision 1 / DRAFT supersedes the unexecuted TASK-004-E; do not execute E separately. TASK-005-A combines admin
  loan-option validation/payload normalization, safe failure feedback, duplicate-mutation protection and deterministic
  behavioral tests while leaving internal scoped design choices to the executor. It is the only selected task. The
  executor must present its own plan and wait for explicit approval before editing.
- TASK-005-A is `NEEDS_CORRECTION` after independent review. Analyzer and all 43 Flutter tests pass, and its local API
  boundary/duplicate guards are sound, but allow-list input formatters silently transform malformed pasted/typed text
  before validation (for example `1e3` -> `13` and month `1.5` -> `15`). Also, the safe-error filter can expose common
  SQL detail forms such as `SQLSTATE[...] detail=...`. A focused correction must add widget-level destructive-filter
  regression cases, reject rather than transform those inputs, and broaden safe detail/control-character rejection.
  Do not proceed to another product task until this correction is reviewed.
- Selected correction: [TASK-005-A1](../tasks/TASK-005-A1.txt), revision 1 / DRAFT. It may modify only the admin page,
  form logic, and their two focused tests, plus create its own report. It must reject malformed text through the real
  widget path without silent filtering, harden diagnostic/control-character error suppression, and preserve the full
  TASK-005-A workflow. Executor plan approval is still required.
- TASK-005-A plus correction A1 are technically `VERIFIED`, pending explicit user acceptance and physical
  iPhone/browser validation. A1 removed destructive character-filtering while preserving numeric keyboard hints,
  proves seven malformed inputs remain intact/rejected with zero mutations, and suppresses SQLSTATE/database/path/
  control diagnostics without hiding the approved concise API messages. Independent review passed focused analysis,
  21/21 pure tests, 26/26 page tests and 53/53 full Flutter tests; the frontend detector found no mechanical issues.
  No live API, DB, account, runtime or unrelated production boundary changed. No next task is selected automatically.
- Combined review of the prior C-G queue: 257/257 policy tests pass and the full suite passes 290 with the same five
  preexisting failures, but the queue remains NEEDS_CORRECTION as non-blocking technical debt. TASK-003-C has no
  report and its weak assertions remain; E still sorts one collision result; F inherits process.env and duplicates
  one isolation block; G retains misleading persistence/prototype language. D appears complete. Do not reopen these
  items during TASK-004-A; revisit only when required by related product work.
- Historical reduced queue prepared at the user's request: [TASK-003-C](../tasks/TASK-003-C.txt),
  [TASK-003-D](../tasks/TASK-003-D.txt), [TASK-003-E](../tasks/TASK-003-E.txt),
  [TASK-003-F](../tasks/TASK-003-F.txt), [TASK-003-G](../tasks/TASK-003-G.txt). It is no longer selected work;
  the combined review result above supersedes its former execution order without accepting the remaining debt.
- [TASK-003-B](../tasks/TASK-003-B.txt) is independently VERIFIED, pending an explicit ACCEPTED label. Its one-line
  number-classification correction passed 206/206 targeted tests; the full backend suite passed 239 and failed the
  same five preexisting loan-request-create tests. Its executor report is tasks/TASK-003-B-report.md.
- [TASK-003-A](../tasks/TASK-003-A.txt) is PAUSED, not accepted. Its tests-first checkpoint changed the two
  policy test files. Before TASK-003-B's fix, independent review reproduced 206 targeted tests: 122 passed and 84 failed; all 84
  failures were the same NaN/Infinity/-Infinity INVALID_TYPE-versus-INVALID_VALUE defect exercised through
  validator, snapshot and serializer. Its broader coverage/import/comment/report work remains pending.
- [TASK-003](../tasks/TASK-003.txt) remains NEEDS_CORRECTION, not accepted. Its exporter already exists;
  preserve it, do not restart the original task or add another feature. No executor was launched by the planner.
  Earlier reports stay read-only; TASK-003-B evidence belongs only in tasks/TASK-003-B-report.md.
- User explicitly requested the new TASK-003 identifier and related addition while TASK-002 was unresolved.
  This is a selected correction/continuation, not acceptance or an automatic next task. Do not run both contracts.
- Outstanding application task: [TASK-002](../tasks/TASK-002.txt), revision 1 / 2026-09-19, NEEDS_CORRECTION
  from the prior technical review in this conversation. The original contract's DRAFT label is historical;
  the worker submitted an implementation/report, but it has not been accepted. No executor was launched by the planner.
  The worker report claims user approval; that approval was not independently verified from its OpenCode conversation.
- TASK-002 historical scope: pure loan-policy validation/snapshot module and isolated tests, no live wiring,
  database changes, migrations, financial-calculation changes or UI. Its report remains tasks/TASK-002-report.md.
- Prior review evidence (2026-09-19, not rerun for this documentation update): 145 targeted tests passed;
  full backend suite had 178 passed / 5 failed. Independent probes found explicit undefined values were not
  REQUIRED, wrong scalar types were misclassified, and duplicate path/code errors could occur. Tests encoded
  some incorrect expectations; snapshot limitation comments and baseline-report evidence also needed correction.
- Historical preparation recheck (2026-09-20): the then-existing loan-policy suite passed 145/145 tests; three independent
  in-memory examples reproduce all three error-contract defects. Those passing tests do not establish correctness.
  Only this pure suite/probes were rerun in that preparation; later full-suite results are recorded below.
- Historical TASK-003 preparation validation: 74 structure/link/contract-example checks passed, zero failed. A read-only
  peer review checked the task's examples and approval/scope consistency. The scoped 131-file preexisting
  source/reference inventory, old task artifacts, runtime runbook and Git index remained unchanged.
- Latest TASK-003 review (2026-09-20): direct policy/export tests passed 70/70; syntax/check commands passed.
  Full backend tests, rerun with required local-port permission, passed 103 and failed the same five preexisting
  loan-request-create cases (names/assertion signatures matched prior evidence). No new full-suite failure found.
  Independent in-memory probes passed 125/146; all 21 failures were NaN/Infinity/-Infinity returning INVALID_TYPE
  instead of INVALID_VALUE across seven numeric fields. Required-field/wrong-type/dedup fixes and JSON output improved.
- Still missing: complete contract-derived regression coverage, actual fresh-child import tests in both files,
  accurate snapshot/serialization limitation comments, coverage matrix and traceable report evidence.
  The review's fresh-child checks passed, but that does not supply the worker's missing saved regression tests.
  Earlier run/approval/provider claims in the worker report are not independently authenticated here.
- Next step: OpenCode reads TASK-003-C only, presents its brief plan and waits for explicit approval. It must not
  start D-G automatically or resume TASK-003-A as one broad unit. No app edits were made by this supervisor during review/preparation;
  tests used pure/mocked inputs, with no live database access or app-runtime changes. No commit or push.
  Do not execute TASK-001/TASK-001-A, start TASK-004 or mark any policy task accepted without review/user acceptance.

## Product direction (unchanged)

- Resume development against the client's Actualizacion.pdf with adjustable business parameters;
  this conversation remains planner/reviewer, OpenCode implements after approval.
- User confirmed the final delivery targets Google Play and App Store, exclusively Dominican Republic.
  Business values should be admin-configurable. Versioned policies should preserve accepted loan
  conditions rather than silently changing old loans when a future configuration changes.
- Client is a law firm (user-reported). Its responsibility for legal conditions does not prove an
  exemption: none has been supplied/verified. Continue technical development; production activation
  and store compliance remain separate validation gates, not claims made by a structural validator.
- PDF comparison, 2026-09-19: all 16 pages/29 sections reviewed against active backend/Flutter source.
  Existing manual lending/document/payment flows are reusable. AI/bureau/scoring, games/ad rewards,
  XP/missions/referrals and versioned credit policies were not found in inspected active source.
  Backend rate interpretation is annual; the PDF specifies monthly. Flutter/backend use different
  installment formulas. Rank advancement currently occurs on approval rather than qualified
  completion plus reengagement. These are scoped findings, NOT authorization for concurrent fixes.
- Historical TASK-002 preparation changed documentation only. Its later implementation and review are recorded
  above; the preparation record must not be mistaken for the current implementation status.

## Previous governance work (historical record)

- Earlier 2026-09-20 update introduced both LIGHTWEIGHT and FORMAL routes in AGENTS, WORKFLOW, context,
  README and the two templates. Its 52 structural/preservation checks and 18 link/anchor checks passed.
  The scoped 131-file source/reference inventory, including runtime runbook, task artifacts, parent AGENTS
  and Git index, was unchanged. That documentation-only update ran no app tests or runtime/DB operations.
- Current request: consolidate/improve agent instructions and continuity, preserving the established runtime.
- Latest clarification applied: shared instructions/context/templates are supervisor-owned and read-only to OpenCode executors;
  the previous permission to update CURRENT_STATE directly has been removed from workflow and task templates.
- Ownership follow-up validation: 20 documentation/integrity checks passed, zero failed; the 256-file non-document
  inventory and Git index still matched the prior baseline. This verifies the written policy, not filesystem enforcement.
- Scope: documentation only; user clarified and approved the workflow during this conversation.
- Application coding task at that earlier documentation handoff: NONE.
- `TASK-001.txt` and `TASK-001-A.txt`: historical attempts. Do not execute/retry them based on filenames or old messages.
- Next action after documentation delivery: await the user's selected development objective;
  inspect its current state and prepare one fresh task using tasks/TEMPLATE.txt. Do not generate it automatically.
- Documentation state: READY_FOR_REVIEW; no user acceptance is implied by file creation.
- Documentation validation on 2026-09-19: 39 structural/link/preservation checks passed, zero failed.
  Checks covered local links, the nine required task headings, approval/data/runtime boundaries, inactive historical tasks,
  text integrity and preservation of the original AGENTS content (apart from one terminal newline).
- The pre/post SHA-256 inventory of 256 non-document source/reference files was unchanged, as was `.git/index`.
  Source inventory hash: `9e6509e2bad9db3cff93d02d34c8f23f4bd88bfc4002e9a13c387ac34a780f5e`.
  This inventory excluded generated/dependency data and secrets; it is not a DB backup or full-environment snapshot.
- Application tests executed for this documentation task: NONE. No app code, DB, runtime service, commit or push was changed.

## Canonical source and historical identity

Repository: `/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos`
Expected branch: `codex/resume-local-dev`.

Observed during the 2026-09-19 read-only audit: HEAD and local branch/cached remote refs at `5b2edaf`,
dated 2026-01-06, with substantial staged/unstaged/untracked work. The local reflog did not establish the
user's reported recent commits/rollback. No live remote comparison or investigation of other copies was performed.
Do not interpret cached `origin/main` as a current GitHub check.

User confirmation: this canonical application's present version is their stable reference; earlier work also occurred
in a Software Jordano Ventura folder. That history is not authorization to use or merge another folder.
“Stable” is user-reported working experience, not a full financial/security acceptance or a clean committed snapshot.
HEAD alone does not preserve the current application. Existing dependency-removal staging is unrelated work.

## Architecture map — inspect the relevant area, not the entire repository

- `backend/index.js`: Express app, route mounts, CORS, health endpoints and runtime boot tuning.
- `backend/routes/`, `controllers/`, `models/`, `middleware/`, `services/`: API/auth, PostgreSQL SQL,
  loans/options/signatures, installments/receipts, document status, news, suggestions, notifications and optional outbound services.
- `backend/package.json`: Node scripts; Node >=18.11 declared, Express ^5.2.1, pg, JWT/bcrypt, Multer, PDFKit, Nodemailer;
  tests use node:test and Supertest. These are declared constraints, not a verified installed toolchain inventory.
- `software1/pubspec.yaml`: Flutter app; Dart ^3.8.1 declared. HTTP, SharedPreferences, file/image picking and document opening.
- `software1/lib/main.dart`: startup/routes; `main_home_page.dart`: active shell; `news_page.dart`: active news.
- `software1/lib/config/api_config.dart`: build-time API base selection.
- `software1/lib/utils/auth_session.dart`: token/session restore/clear. Login stores current and legacy token keys.
- `software1/lib/services/loan_installments_service.dart`: installment API helper; many other HTTP calls remain in screens.
- `software1/lib/utils/`: conditional web/IO document and receipt opening; preserve platform boundaries.
- `software1/backend/`: residual copy, never the active backend. Root node_modules/package residues are not the active Node project.
- Photos, signatures, documents and receipts can be PostgreSQL BYTEA/base64; inspect each upload/download path before assuming files.

Avoid importing backend modules for “read-only” analysis: db.js may connect, index.js boot performs schema/data tuning.
Historical SQL migrations are not a complete ordered bootstrap. Do not run them as a generic fix.

## Runtime reference — recheck live state when asked

- iPhone Safari: `https://johans-macbook-pro.tailfbc2ea.ts.net:7358` → Flutter `:7357`.
- API: `https://johans-macbook-pro.tailfbc2ea.ts.net:3001` → backend `:3000`.
- Existing local PostgreSQL only; no external `5432`.
- CORS must allow the exact frontend HTTPS origin. Preserve unrelated Tailscale/OpenCode mappings.
- Full commands and safety boundaries: RUNTIME_RUNBOOK.md.
- User describes the current app as running/stable. This documentation task did not inspect live listeners,
  start/stop services, verify current CORS, log in, or test a physical iPhone. No current PID/health claim is made here.
- Historical `scripts/dev/` launchers conflict with current instructions. They remain unchanged and must not be run unreviewed.

## QA/database decisions

- Reuse the existing local DB and existing accounts. No per-agent DB, new login, reset or seed.
- Approved QA may create identifiable test records with existing accounts.
- Specific permission is required for preexisting loan/payment/document/account changes, including indirect category/counter effects.
- No automatic cleanup or restore. Mock edge cases when safe real-data targets/permissions are unavailable.
- User reports an existing backup; its freshness, location and contents were not inspected in this task.
  Fresh private local backups are allowed when needed before consequential writes, under WORKFLOW safeguards.
- Required account roles/secure access have not been inventoried under this workflow. Ask only if a task needs missing access;
  do not hard-code credentials from an old conversation or create replacement users.
- Disable/mock actual outbound paths. EMAIL_OUTBOX_DISABLED alone is not proof that direct SMTP is disabled.

## Verified code observations versus old descriptions

Read-only audit, 2026-09-19; these are not new test results or permission to fix the code:

- The loan-request creation controller now looks up the selected option and persists its terms.
  Old TASK-001/context descriptions of undefined variables and trusting body terms must not be replayed blindly.
  Edge-case correctness still requires a fresh scoped review; the old task has not been accepted under this workflow.
- Backend email lookup/registration does not consistently normalize case; the original AGENTS claim was too broad.
- Approval/status, installment generation, signatures, document bitmask and receipt behavior are shared contracts.
  Existing formulas are implementation facts, not user-approved financial specifications to invent or alter casually.
- Backend has isolated test files under backend/test; frontend tests cover session/initial login behavior.
  Mock/HTTP-smoke tests do not prove real DB schema, every user flow, or physical Safari.
- npm run check uses find -exec and can hide individual syntax failures in its final exit code.
  Use direct node --check on changed JS files and inspect output.
- Historical “20 tests passed”, “6 tests passed”, build results and dated runtime claims are not current verification.

## Documentation source of truth

- AGENTS.md: compact shared rules inside the real repository.
- docs/WORKFLOW.md: task/approval/review/QA/handoff contract.
- docs/RUNTIME_RUNBOOK.md: complete standardized operation and safe runtime repairs.
- docs/CURRENT_STATE.md: supervisor-owned continuity record; supervisor updates it after reviewing execution/handoff evidence.
- tasks/TEMPLATE.txt and tasks/REPORT_TEMPLATE.md: task and evidence formats, not active work.
- README.md: human entry point, linking to the same sources instead of duplicating operational commands.
- Parent ../AGENTS.md: redirect only; not an independent copy of the rules.
- docs/PROJECT_CONTEXT.md and docs/LOCAL_DEVELOPMENT.md: historical references with explicit warnings.
- docs/archive/AGENTS-before-2026-09-19.md: original instruction text for preservation/audit, not active authority.

Supervisor updates record what was observed and when. Keep historical observations dated; never convert unchecked claims into “passed”.
Only store the next authorized action, not a large executable backlog.
