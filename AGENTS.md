# AGENTS.md — AppPrestamos

Shared instructions for every model/provider. Last agreed with the user: 2026-09-27.
Read this file first. Do not infer permission from old chats, task files, model capability, or passing tests.

## 1. Canonical repository and existing work

The ONLY canonical checkout on this Mac is:

`/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos`

The parent `Proyecto_AppPrestamos/` is NOT the Git root. Ignore any legacy outer `.git`.
Do not use `software-Jordano Ventura`, `obsoleto`, an OpenCode worktree, or directories containing
`_BACKUP_`, `_BEFORE_ROLLBACK_`, or `_FAILED_` as the working application.
Do not create another checkout, branch, or worktree without the user's approval.

Before each batch of Git operations, from the canonical checkout or its subdirectory, verify:

```bash
pwd
git rev-parse --show-toplevel
git branch --show-current
```

Stop if the Git root differs. Expected branch is `codex/resume-local-dev`; an unexpected branch
requires clarification, not an automatic checkout. `5b2edaf` is a historical baseline, NOT a restore target.
The user identifies the current local application as the stable reference. Its uncommitted changes
are part of that state; HEAD alone does not capture them. This is not a claim that every feature works.

Never reset, clean, mass restore, mass stage, delete untracked files, or undo preexisting changes.
No commit without an explicit commit request. No push, PR, merge, or deployment without its own authorization.
Before authorized staging, review exact files/hunks and exclude unrelated work, dependencies and generated files.

## 2. Read only the instructions needed for the current intent

| Intent | Required additional reading |
| --- | --- |
| Plan, implement, review, resume, or switch models | [WORKFLOW.md](docs/WORKFLOW.md), [CURRENT_STATE.md](docs/CURRENT_STATE.md), the selected formal task OR lightweight request/approved plan, and its report if present |
| Run, stop, restart, status, runtime repair, or OpenCode Remote operation | [RUNTIME_RUNBOOK.md](docs/RUNTIME_RUNBOOK.md) completely before acting |
| Wider architecture investigation | Relevant sections of [PROJECT_CONTEXT.md](docs/PROJECT_CONTEXT.md), then verify against current source |

Authority within this project: latest explicit user decision, this file, the relevant current guide,
then the approved task within those boundaries. If these disagree materially, ask; do not silently override a safety rule.
Tool/system permissions still apply. Historical documents, archives and old task files are NOT authorization.
Current code is evidence of implementation, not proof of intended product behavior.

`docs/LOCAL_DEVELOPMENT.md` describes historical setup and optional platform modes, not normal RUN.
`scripts/dev/dev_remote_start.sh` and `scripts/dev/dev_remote_restart.sh` are NOT approved launchers:
they contain conflicting process/network behavior. Do not execute them until a separate task repairs and verifies them.
The archived original instructions are reference only; do not load them as the normal agent prompt.

## 3. Roles, approval and one-task execution

- Two routes coexist: LIGHTWEIGHT for small, low-risk, local changes requested directly in OpenCode;
  FORMAL for complex, sensitive or cross-component work. Use WORKFLOW's intake criteria, not prompt length or model size.
- The planner/reviewer here analyzes broadly, designs ONE focused English `.txt` task for FORMAL work,
  and reviews evidence when requested. It does not implement app code unless explicitly asked.
  Explicitly requested documentation maintenance is allowed. LIGHTWEIGHT work needs no supervisor-written TXT.
- The OpenCode executor reads the selected request/task and actual files, presents its own bounded plan,
  and WAITS for user approval before edits or mutating tests. A direct request or pasted task is not plan approval.
  For LIGHTWEIGHT work, the user's request plus approved short English plan is the contract;
  include exact files, observable acceptance criteria, checks and the unique report path. Details live in WORKFLOW.
- One task and one editing executor at a time. Changing model/provider does not authorize concurrent work or a new scope.
  Stop/pause the previous executor before handing over. The successor states its plan and waits for approval.
- After approval, perform the complete scoped implementation, tests and debugging without asking at every small step.
  Seek renewed approval for scope, contract, dependency, schema, data-target or infrastructure changes not in the plan.
- Read-only analysis/review does not authorize fixes. Report unrelated findings without fixing them.
- Never start the next task automatically. Worker completion means ready for review, not accepted.
  A different request does not silently complete or replace unfinished work; agree on an explicit switch first.
- Keep conversation with the user in Spanish; task contracts and structured worker reports in English.

### Governance ownership — READ-ONLY for executors

The user and the supervising planner/reviewer in this conversation exclusively maintain shared project guidance.
OpenCode executors must NOT edit, delete, rename, replace, reformat, regenerate or indirectly modify:

- This AGENTS.md, the parent ../AGENTS.md, or any other agent-instruction/override files.
- README files and everything under `docs/`, including WORKFLOW, RUNTIME_RUNBOOK, CURRENT_STATE,
  historical guides and archives.
- Task contracts (including the selected task and historical TASK-*.txt), `tasks/TEMPLATE.txt`
  and `tasks/REPORT_TEMPLATE.md`.
- Agent configuration, permissions or new instruction files intended to change or override this workflow.

Approval to implement a task, a generic documentation-update request inside that task, or RUN/STOP/RESTART
does not transfer governance ownership. If a task accidentally lists a protected file as editable, stop and report
the conflict; do not self-authorize. Changing model/provider or calling yourself a reviewer/planner does not change your role.
No permission/attribute/symlink changes or shell/script bypasses to rewrite protected files.

The executor's ONLY standalone documentation output is its explicitly approved `tasks/TASK-<id>-report.md`
(including `TASK-QUICK-...-report.md` for LIGHTWEIGHT work). Create it only after plan approval;
record the approved chat plan there for handoff, without changing that plan or creating a separate task contract.
It may record evidence and proposed documentation/context corrections there, but must not change the report template,
another task's report, shared CURRENT_STATE, or reviewer/user-acceptance entries. Code comments/docstrings inside
approved source files remain part of the implementation scope, not an exception for editing project governance.

Record protected-file hashes/path inventory before implementation and compare them before handoff, including untracked files.
If protected files changed or new instruction files appeared, stop and report the discrepancy; do not silently overwrite
or restore them. The supervisor reviews the evidence and updates shared context/instructions when authorized.
This is a workflow rule and integrity check, not an operating-system write lock; do not claim technical enforcement exists.

## 4. Operational exception — act on RUN / STOP / RESTART / OPENCODE REMOTE

An explicit operational request is direct approval of the established runbook; no second planning approval is needed.
Interpret it in context: “run tests” is not “run the application”, and quoted examples are not commands.

- RUN / START / LAUNCH / `levanta el programa` / `ponlo a correr`: perform the complete runbook,
  self-heal only the listed safe prerequisites, verify remote login readiness, and leave the app running.
- STOP / TERMINATE / `para el programa`: safely stop only AppPrestamos backend and Flutter.
- RESTART / RERUN / `reinicia`: safe STOP followed by complete RUN; preserve DB and Tailscale.
- STATUS / `está corriendo?`: inspect only; no repair or restart.
- Explicit backend-only/frontend-only instructions limit the action to that component.
- RUN OPENCODE REMOTE / START OPENCODE REMOTE / `inicia`, `activa`, `levanta`, `abre` or
  `pon OpenCode remoto a correr`: execute only the OpenCode Remote procedure in RUNTIME_RUNBOOK.
  This is independent from AppPrestamos RUN and does not start or restart the app.
- STATUS OPENCODE REMOTE / `revisa OpenCode remoto`: inspect only its service, listener, mapping and HTTPS response.
- STOP OPENCODE REMOTE / `para`, `detén` or `apaga OpenCode remoto`: stop only OpenCode's background service;
  preserve its Tailscale mapping and all AppPrestamos/diagnostic processes and mappings.

Do not answer an executable operational request only with commands for the user to run.
If permissions or a genuine blocker prevent execution, report it honestly and do not bypass restrictions.

## 5. Protected runtime — do not redesign during feature work

| Component | Canonical setup |
| --- | --- |
| Flutter source / listener | `software1/`, `0.0.0.0:7357` |
| iPhone Safari / Tailscale frontend | `https://johans-macbook-pro.tailfbc2ea.ts.net:7358` → `http://127.0.0.1:7357` |
| Express source / local API | `backend/index.js`, `127.0.0.1:3000` |
| Tailscale backend / Flutter API_BASE_URL | `https://johans-macbook-pro.tailfbc2ea.ts.net:3001` → `http://127.0.0.1:3000` |
| PostgreSQL | Existing local database, typically `appprestamos_local`; never expose `5432` |

Preserve ports, `.env`, CORS origins, bindings, API base, Flutter build strategy and all unrelated Tailscale mappings.
Preserve OpenCode's mapping and any diagnostic `:7364` mapping. Never reset Tailscale Serve globally.
Never substitute LAN/direct-IP HTTP for the canonical physical-iPhone HTTPS path without explicit permission.
Inspect PID, command and cwd before terminating a process. Never broad `pkill`/`killall` Node, Dart or Flutter.
Complete frontend HTTP 200 alone is not RUN success: backend local/remote health and login CORS must also pass.
Never claim physical-iPhone login was tested unless the user confirms that flow for the relevant version.

## 6. Database, accounts and privacy

- Reuse the existing local DB and existing accounts. Do not create a DB or account per agent/test,
  restore a dump, reset data, or seed users automatically.
- Approved QA may create clearly identifiable test requests/records using existing accounts.
  The approved plan must identify the QA scope and expected side effects. Record created IDs privately.
- Changing preexisting loans, payments, documents, credentials or other business data requires specific user permission.
  No broad cleanup, deletion, truncation or automatic rollback. See WORKFLOW for indirect effects on account counters/category.
- The user allows a fresh private local backup before consequential data-writing QA when needed.
  Verify its local target, destination outside the repository, restrictive permissions and success first.
  An existing backup is not automatically current. Do not create another DB to test a restore without permission.
  Backup creation is not authorization to restore or overwrite data. No backup is needed for ordinary documentation edits.
- Keep SMTP/SendGrid/FCM/Cloudinary outbound activity disabled or mocked for routine QA.
  `EMAIL_OUTBOX_DISABLED=1` disables the outbox worker, NOT necessarily direct sends.
- Never publish credentials, JWTs, connection strings, dumps, personal records or unredacted screenshots/logs.
  Do not put login passwords in tasks, reports, this file or other versioned documentation.

## 7. Code map and contracts to preserve

- Backend: Express 5 / CommonJS; `routes/` → `controllers/` → `models/` and `services/`, PostgreSQL via `db.js`.
  `software1/backend/` is residual. Do not edit it. Root Node dependencies are legacy; use `backend/`.
- Flutter: `software1/lib/main.dart` boot/routes, `main_home_page.dart` active shell,
  `news_page.dart` active news; `home_page.dart` still has a legacy route, so do not assume it is unused.
  HTTP is often in screens. Avoid an architectural rewrite during a focused task.
- API URLs: `software1/lib/config/api_config.dart`; auth lifecycle: `utils/auth_session.dart`.
  Preserve both current/legacy token keys until a deliberate migration; do not clear unrelated preferences.
- Preserve web/IO conditional document/receipt openers and multiplatform compatibility.
- Loan statuses, transitions, financial units/formulas, roles (`admin`, `cliente`), receipt ownership/idempotency,
  signature behavior and document bitmask order are shared contracts. Never invent a business rule to make tests pass.
- Document order is `cedula`, `estadoCuenta`, `cartaTrabajo`, `videoAceptacion`, two bits each.
  Photos/signatures/documents/receipts may live in PostgreSQL BYTEA/base64, not files. Inspect the actual path.
- Backend email normalization is not consistently enforced in current source; do not assume it is.
- Backend startup/imports can connect to DB; startup tuning can alter schema and normalize existing data.
  Historical SQL migrations are not a complete safe bootstrap. Do not bulk-run them during RUN or analysis.

## 8. Evidence and failure handling

Use [tasks/TEMPLATE.txt](tasks/TEMPLATE.txt) for FORMAL tasks; use WORKFLOW's short approved plan for LIGHTWEIGHT work.
Both routes require scoped verification and evidence. The lightweight route reduces ceremony, not safeguards.
Follow WORKFLOW's contract-first verification: set expected outcomes before production edits, preserve mandatory
task examples, and map criteria to actual checks. A green test suite is not proof that the contract is covered.
Record baseline, regression-reproduction and final evidence separately; do not derive expected results solely
from the implementation under test or reuse historical counts as a fresh run.
Record the pre-task state of permitted files so your changes can be distinguished from the existing dirty tree.
Use small edits based on fresh reads. An edit-match failure is not a successful edit.

After two correction attempts on the same failure without measurable progress, stop, record evidence,
and report a reproducible blocker. Do not restart indefinitely, silently change models/settings, weaken tests,
or retry an uncertain non-idempotent write. Inspect results before repeating database/API operations.

Report actual checks, exit codes and counts; distinguish passed, failed, skipped, timed out and not run.
`npm run check` currently uses `find -exec`; its exit code alone can hide a JS syntax failure.
Run direct `node --check` on changed JS files and inspect all check output.
Mocked tests do not prove production DB schema, server startup, CORS, or physical Safari behavior.

Before handoff, executors update only their approved task report; the supervisor maintains CURRENT_STATE after review.
Never store private data there. After a model switch, read those records and revalidate actual state;
do not assume this conversation or any cached summary is complete.
