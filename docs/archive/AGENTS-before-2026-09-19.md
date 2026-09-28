# Archived AGENTS.md — before the 2026-09-19 workflow update

Historical reference only. NOT active instructions and NOT a task authorization.
Use ../../AGENTS.md and ../RUNTIME_RUNBOOK.md for current rules.
The original text below is preserved without content changes; only a terminal newline was added.
The SHA-256 of the original bytes (before that final newline) is
ca7d4d46cb2f0f9c81b98fb79422b3296400f8f847a0b87767ea34527d3d3959.
Do not follow this archive when it conflicts with the current workflow.

<!-- ORIGINAL DOCUMENT START -->
# AGENTS.md — AppPrestamos

## Repository identity — CRITICAL

The real Git repository root is:

`/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos`

Short form:

`AppPrestamos/`

It is NOT the parent directory:

`/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos`

Expected working branch / known baseline:

- Branch: `codex/resume-local-dev`
- Known baseline commit: `5b2edaf`
- The working tree may contain legitimate uncommitted changes.

Before any Git operation, always verify:

```bash
pwd
git rev-parse --show-toplevel
git branch --show-current
```

The Git top-level MUST be:

```text
/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos
```

Do not perform Git operations from the parent directory.

The parent directory may contain an accidental/legacy outer `.git`.

Ignore it.

Never run any of the following without explicit review of the exact scope:

- `git reset --hard`
- `git clean -fd`
- `git restore .`
- `git add -A`
- mass checkout/restore operations
- mass deletion of untracked files

Do not assume a dirty working tree is disposable.

Directories whose names contain:

- `_BACKUP_`
- `_BEFORE_ROLLBACK_`
- `_FAILED_`

are safety/reference copies.

They are NOT the canonical working repository.

Never run the application from those copies.

---

# CRITICAL — Natural-language operational commands

The user frequently gives short operational instructions.

Agents MUST interpret them according to this section.

Do not respond to an operational command merely by explaining how the user could do it.

Unless a blocker genuinely prevents execution, perform the requested action.

## RUN intent

The following phrases, and semantically equivalent phrases, mean:

**Start AppPrestamos using the complete canonical remote-development setup and leave it running.**

Examples:

- `run`
- `run the program`
- `run program`
- `start`
- `start the program`
- `start app`
- `start AppPrestamos`
- `launch`
- `launch the program`
- `run everything`
- `levanta el programa`
- `corre el programa`
- `ejecuta el programa`
- `inicia el programa`
- `pon el programa a correr`

When the user gives RUN intent, the agent MUST:

1. Work from the real `AppPrestamos` repo.
2. Read this `AGENTS.md`.
3. Inspect existing backend and Flutter processes.
4. Reuse healthy canonical processes if they are already running.
5. Stop stale processes from backup/rollback copies if necessary.
6. Preserve unrelated processes and Tailscale mappings.
7. Ensure canonical backend CORS is configured.
8. Ensure canonical Tailscale Serve mappings exist.
9. Ensure `software1/build` is usable.
10. Start/restart backend if necessary.
11. Start/restart Flutter if necessary.
12. Verify backend locally.
13. Verify backend through Tailscale.
14. Verify login CORS preflight.
15. Verify frontend locally.
16. Verify frontend through Tailscale.
17. Leave backend and Flutter running.
18. Report the physical-iPhone Safari URL.

The canonical user-facing URL after RUN is:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

RUN is not successful merely because Flutter compiled.

RUN is not successful merely because the frontend returns HTTP 200.

RUN requires the server-side path needed for login to be functional too.

---

# RUN means self-healing the known setup

When executing RUN, the agent is authorized to repair the small set of known runtime prerequisites described below.

Do NOT stop at:

> "CORS is wrong."

or:

> "The Serve mapping is missing."

or:

> "Port 7357 is occupied."

If the repair is safe and covered by this file, perform it.

## Allowed automatic RUN repairs

During RUN, the agent MAY automatically:

- add the canonical Tailscale frontend origin to `CORS_ORIGINS`
- preserve all existing valid CORS origins while doing so
- recreate a missing canonical Tailscale Serve mapping
- stop a stale AppPrestamos process from a backup/rollback directory
- restart the canonical backend so `.env` changes take effect
- restart canonical Flutter
- remove ONLY a broken `software1/build` symlink pointing to an OpenCode temp directory
- recreate `software1/build` as a normal directory
- run `flutter pub get` if necessary
- run `npm ci` if dependencies are genuinely missing
- start the already-installed local PostgreSQL service if it is clearly stopped and required

RUN does NOT authorize:

- database restoration
- deleting databases
- replacing `.env`
- changing secrets
- resetting Git
- changing application business logic
- changing canonical ports
- deleting unrelated Tailscale mappings
- exposing PostgreSQL

If a larger change is needed, report the blocker instead of improvising.

---

# STOP intent

The following phrases, and semantically equivalent phrases, mean:

**Stop the AppPrestamos application processes safely.**

Examples:

- `stop`
- `stop the program`
- `stop app`
- `stop AppPrestamos`
- `terminate`
- `terminate the program`
- `kill the program`
- `close the program`
- `para el programa`
- `deten el programa`
- `apaga el programa`
- `cierra el programa`

STOP means:

- stop the canonical Flutter process associated with port `7357`
- stop the canonical backend process associated with port `3000`

STOP does NOT mean:

- stop Tailscale
- reset Tailscale Serve
- delete Tailscale mappings
- stop PostgreSQL
- kill OpenCode
- kill unrelated Node/Dart processes
- delete files
- clean Git

unless the user explicitly asks for one of those.

---

# Safe STOP procedure

Before terminating anything, inspect the process.

Frontend:

```bash
lsof -nP -iTCP:7357 -sTCP:LISTEN
```

Backend:

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
```

For each PID:

```bash
ps -p <PID> -o pid,ppid,lstart,command=
lsof -a -p <PID> -d cwd
```

Verify that the process belongs to AppPrestamos.

Prefer graceful termination:

```bash
kill -TERM <PID>
```

Wait briefly and verify that the port is free.

Do not use `kill -9` first.

Use forced termination only if:

1. the process has been positively identified,
2. graceful termination failed,
3. it is clearly an AppPrestamos process.

After STOP, verify:

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
lsof -nP -iTCP:7357 -sTCP:LISTEN
```

No canonical AppPrestamos process should remain on those ports.

Do not change Tailscale Serve configuration during normal STOP.

The mappings may remain configured while their local targets are offline.

That is expected.

---

# RESTART intent

Examples:

- `restart`
- `restart program`
- `restart the program`
- `rerun`
- `run again`
- `reinicia`
- `reinicia el programa`
- `vuelve a correrlo`

RESTART means:

1. Perform safe STOP for the AppPrestamos backend/frontend.
2. Preserve Tailscale Serve and PostgreSQL.
3. Perform the complete canonical RUN procedure.
4. Revalidate the remote login path.

Do not perform destructive cleanup between STOP and RUN.

---

# STATUS intent

Examples:

- `status`
- `program status`
- `is it running?`
- `esta corriendo?`
- `check the program`
- `check status`

STATUS is read-only.

Inspect:

- real repo
- branch
- backend port `3000`
- Flutter port `7357`
- process cwd
- Tailscale Serve mappings
- backend local health
- backend Tailscale health
- frontend local reachability
- frontend Tailscale reachability
- login CORS preflight

Do not restart or modify anything unless the user also asks for repair/run.

---

# Partial operational intents

If the user explicitly says:

- `run backend`
- `start backend`

start only the backend and verify it.

If the user explicitly says:

- `run frontend`
- `start frontend`

start only Flutter.

If Flutter remote operation requires a backend and the backend is unavailable, report that clearly rather than silently changing unrelated state.

If the user says:

- `stop backend`

stop only the canonical backend.

If the user says:

- `stop frontend`

stop only the canonical Flutter server.

---

# CRITICAL — Stability rule

The working runtime/network infrastructure is part of the project's known-good state.

Feature work MUST NOT casually modify it.

UI work, business logic, database logic, loan behavior, documents, styling, refactors, testing, or unrelated changes MUST NOT silently modify:

- Tailscale Serve mappings
- ports `3000`, `3001`, `7357`, `7358`
- OpenCode's Tailscale mapping
- `API_BASE_URL`
- `CORS_ORIGINS`
- backend binding
- `.env`
- PostgreSQL exposure
- Flutter build-directory strategy
- physical-iPhone access method
- remote-access architecture

Exception:

When the explicit task is RUN/START/RESTART or remote-runtime repair, the narrowly defined self-healing operations in this file are authorized.

Outside those cases, explain why an infrastructure change is needed before making it.

---

# CRITICAL — Canonical remote development setup

The primary development target is Safari on a physical iPhone through Tailscale.

Agents MUST preserve this configuration unless the user explicitly requests a different architecture.

## Canonical topology

### Frontend

Source:

```text
software1/
```

Flutter development server:

```text
0.0.0.0:7357
```

Tailscale Serve:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

proxies to:

```text
http://127.0.0.1:7357
```

Physical iPhone Safari URL:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Do not replace this canonical workflow with direct LAN/Tailscale-IP HTTP access.

---

## Backend

Source:

```text
backend/
```

Local Express API:

```text
127.0.0.1:3000
```

Tailscale Serve:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

proxies to:

```text
http://127.0.0.1:3000
```

Canonical Flutter remote API URL:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

---

## Database

PostgreSQL remains local to the Mac.

Never expose:

```text
5432
```

through:

- Tailscale Serve
- Tailscale Funnel
- LAN
- public interfaces
- internet
- port forwarding

Architecture:

```text
iPhone Safari
    |
    | HTTPS / Tailscale
    v
Frontend :7358
    |
    | Flutter API calls
    v
Backend :3001
    |
    | Tailscale Serve
    v
Express :3000
    |
    v
Local PostgreSQL :5432
```

The iPhone must never connect directly to PostgreSQL.

---

# Tailscale Serve — preserve mappings

Inspect with:

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
```

Canonical AppPrestamos mappings:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
-> http://127.0.0.1:7357
```

and:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:3001
-> http://127.0.0.1:3000
```

OpenCode may use:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net
-> http://127.0.0.1:49374
```

Preserve it.

A previous diagnostic mapping may exist:

```text
:7364 -> :7363
```

Do not remove it as an unrelated side effect.

Never use a blanket Tailscale Serve reset during normal AppPrestamos work.

---

# Repair missing canonical Tailscale mappings

During RUN, if the backend mapping is missing, add ONLY that mapping:

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https=3001 http://127.0.0.1:3000
```

If the frontend mapping is missing, add ONLY that mapping:

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https=7358 http://127.0.0.1:7357
```

Then inspect Serve status again.

Do not disturb other mappings.

---

# CRITICAL — Required CORS

Physical Safari loads the frontend with this Origin:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

The backend MUST allow it.

Canonical development CORS origins include:

```text
http://localhost:7357
http://127.0.0.1:7357
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

An existing LAN fallback such as:

```text
http://100.88.95.23:7357
```

may remain.

Do not remove valid existing origins unnecessarily.

Canonical example:

```text
CORS_ORIGINS=http://localhost:7357,http://127.0.0.1:7357,https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Do not use `*` merely to hide a CORS problem.

---

# Persistent CORS repair during RUN

Before starting/restarting the backend, inspect ONLY the CORS line:

```bash
grep '^CORS_ORIGINS=' backend/.env || true
```

Do not print the entire `.env`.

Do not expose:

- `DATABASE_URL`
- `JWT_SECRET`
- SMTP credentials
- API keys
- other secrets

If the canonical Tailscale frontend origin is missing from `CORS_ORIGINS`, update ONLY that setting.

Preserve all existing valid origins.

Required origin:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Do not create duplicate `CORS_ORIGINS=` lines.

Do not replace or rewrite the entire `.env`.

After repair, verify ONLY:

```bash
grep '^CORS_ORIGINS=' backend/.env
```

Then restart the backend so it reloads the corrected `.env`.

This repair is considered part of RUN.

The agent MUST NOT tell the user to manually fix CORS when this narrow repair can be performed safely.

---

# Authentication remote path

Login endpoint:

```text
POST /login
```

A successful frontend page load does NOT prove login works.

Safari may successfully load:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

while login fails because CORS blocks access to:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

Therefore RUN verification MUST include the login preflight.

---

# Canonical CORS preflight test

Use:

```bash
ORIGIN='https://johans-macbook-pro.tailfbc2ea.ts.net:7358'
API='https://johans-macbook-pro.tailfbc2ea.ts.net:3001'

curl -i -X OPTIONS \
  -H "Origin: $ORIGIN" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type" \
  "$API/login"
```

Success requires a response header equivalent to:

```text
Access-Control-Allow-Origin: https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

A `200` response without this header is NOT a successful CORS check.

---

# Canonical RUN procedure

When the user says RUN, START, or an equivalent phrase, follow this procedure.

## 1. Enter and verify the real repository

```bash
cd /Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos

pwd
git rev-parse --show-toplevel
git branch --show-current
```

Stop if the Git root is not the real `AppPrestamos` repository.

---

## 2. Read runtime state

Inspect:

```bash
git status --short
```

Do not clean the working tree.

Inspect Tailscale:

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
```

Inspect backend:

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
```

Inspect Flutter:

```bash
lsof -nP -iTCP:7357 -sTCP:LISTEN
```

---

## 3. Handle existing processes safely

If port `3000` or `7357` is occupied, inspect each listener:

```bash
ps -p <PID> -o pid,ppid,lstart,command=
lsof -a -p <PID> -d cwd
```

If a healthy canonical AppPrestamos instance is already running, reuse it when possible.

Do not start duplicate servers.

If a process belongs to:

- `_BACKUP_`
- `_BEFORE_ROLLBACK_`
- `_FAILED_`
- another repository

and blocks a canonical port, terminate that stale process gracefully.

Do not kill unrelated processes.

---

## 4. Ensure canonical CORS

Inspect:

```bash
grep '^CORS_ORIGINS=' backend/.env || true
```

Ensure it contains:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Repair minimally if necessary.

---

## 5. Validate Flutter build directory

From the repo root:

```bash
ls -ld software1/build 2>&1
file software1/build 2>&1
readlink software1/build 2>&1 || true
```

`software1/build` may:

- not exist
- be a normal directory

It must NOT remain a broken symlink to a temporary OpenCode path.

Problematic example:

```text
/private/var/.../T/opencode/...
```

If and ONLY if it is a broken temporary OpenCode symlink:

```bash
rm software1/build
mkdir -p software1/build
```

Do not delete a legitimate source directory.

---

## 6. Start/restart backend

If the backend must be started or reloaded, use the real backend:

```bash
cd /Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos/backend
npm start
```

Equivalent entrypoint:

```bash
node index.js
```

Do not run `software1/backend`.

Keep the backend running.

If the execution environment supports managed/background shells, it is acceptable to leave it running there.

Do not start multiple backend copies.

---

## 7. Verify backend locally

```bash
curl --fail http://127.0.0.1:3000/db-health
```

Expected JSON includes:

```text
"ok":true
```

If local health fails, diagnose the backend/database before blaming Tailscale.

---

## 8. Ensure backend Tailscale mapping

Verify:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:3001
-> http://127.0.0.1:3000
```

Create only this mapping if missing.

Then test:

```bash
curl --fail https://johans-macbook-pro.tailfbc2ea.ts.net:3001/db-health
```

Expected JSON includes:

```text
"ok":true
```

---

## 9. Verify login CORS

Run the canonical OPTIONS preflight.

It must include:

```text
Access-Control-Allow-Origin: https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

If it does not:

1. inspect `backend/.env`
2. repair `CORS_ORIGINS` minimally
3. restart canonical backend
4. rerun preflight

Do not proceed while knowingly leaving the remote login CORS broken.

---

## 10. Prepare Flutter

```bash
cd /Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos/software1
flutter pub get
```

---

## 11. Start Flutter with canonical remote API

Use:

```bash
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 7357 \
  --dart-define=API_BASE_URL=https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

Do NOT use this for the physical-iPhone remote instance:

```text
API_BASE_URL=http://127.0.0.1:3000
```

Do NOT substitute:

```text
http://100.88.95.23:3000
```

Do NOT substitute a LAN IP unless specifically debugging LAN mode.

Keep Flutter running.

---

## 12. Ensure frontend Tailscale mapping

Verify:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
-> http://127.0.0.1:7357
```

Create only this mapping if missing.

---

## 13. Verify frontend

Local:

```bash
curl -I http://127.0.0.1:7357
```

Tailscale:

```bash
curl -I https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Both must reach the Flutter web application.

---

## 14. Leave application running

After successful RUN:

- backend remains running
- Flutter remains running
- Tailscale remains connected/configured
- PostgreSQL remains local
- Serve mappings remain configured

Report:

```text
AppPrestamos is running.

iPhone Safari:
https://johans-macbook-pro.tailfbc2ea.ts.net:7358

Backend:
https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

Do not claim physical login was tested unless the user actually tests it.

---

# Canonical STOP procedure

When the user asks to STOP the program:

## 1. Find backend listener

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
```

If present, inspect:

```bash
ps -p <PID> -o pid,ppid,lstart,command=
lsof -a -p <PID> -d cwd
```

If it is AppPrestamos, terminate gracefully:

```bash
kill -TERM <PID>
```

---

## 2. Find Flutter listener

```bash
lsof -nP -iTCP:7357 -sTCP:LISTEN
```

Inspect:

```bash
ps -p <PID> -o pid,ppid,lstart,command=
lsof -a -p <PID> -d cwd
```

If it is AppPrestamos Flutter, terminate gracefully:

```bash
kill -TERM <PID>
```

Because Flutter may have a parent/child process relationship, verify the listener actually disappears.

Do not blindly kill every `dart`, `dartvm`, or `flutter` process on the machine.

---

## 3. Verify stopped

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
lsof -nP -iTCP:7357 -sTCP:LISTEN
```

Normal STOP ends here.

Do NOT:

- reset Tailscale
- delete Serve mappings
- stop Tailscale
- stop PostgreSQL
- delete `.env`
- delete build files
- clean Git

unless specifically requested.

---

# Canonical RESTART procedure

For RESTART:

1. Safe STOP.
2. Verify ports `3000` and `7357` are free.
3. Preserve Tailscale Serve.
4. Preserve PostgreSQL.
5. Perform complete RUN.
6. Revalidate CORS/login preflight.
7. Leave servers running.

---

# Physical-iPhone verification boundary

The agent can verify server-side readiness.

The physical user interaction must be distinguished from automated checks.

After successful RUN, tell the user to open:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

If the user confirms login works, it is valid to say physical-iPhone login is confirmed.

If not personally/user-confirmed, report:

```text
Server-side remote workflow verified.
Physical iPhone login awaits user validation.
```

Never falsely claim an iPhone login was tested.

---

# If physical iPhone login still fails

If all of these pass:

- frontend `:7358`
- backend `:3001/db-health`
- canonical API base URL
- OPTIONS `/login`
- correct `Access-Control-Allow-Origin`

but Safari still shows a login connection error:

Do NOT redesign networking.

Next inspect:

- actual `POST /login`
- backend logs
- response status
- request body
- content type
- Flutter error handling
- authentication response
- Safari-specific browser behavior

The debugging order is:

```text
frontend reachability
-> backend reachability
-> API_BASE_URL
-> CORS preflight
-> actual POST /login
-> application/auth behavior
```

---

# Failure classification — do not conflate failures

## Safari cannot open page

This indicates primarily:

- frontend server unavailable
- port `7357` unavailable
- Tailscale Serve issue
- Tailscale disconnected
- wrong URL
- stale/wrong process

Do not immediately diagnose Flutter rendering.

---

## Safari loads page but page is blank

Network reachability succeeded.

Investigate:

- Flutter runtime
- JavaScript exceptions
- assets
- renderer
- service worker
- web compatibility

Do not classify as basic Tailscale connectivity.

---

## Safari loads page but login says "connection error"

Frontend reachability already works.

Investigate:

1. canonical `API_BASE_URL`
2. backend `:3001`
3. `/login`
4. CORS configuration
5. OPTIONS preflight
6. POST request
7. application/auth response

Do not rebuild the whole environment first.

---

# Project structure

Real backend:

```text
AppPrestamos/backend/
```

Technology:

```text
Express 5
```

Real backend entrypoint:

```text
backend/index.js
```

Flutter frontend:

```text
AppPrestamos/software1/
```

Dart SDK constraint currently declared by the project:

```text
^3.8.1
```

Residual backend:

```text
AppPrestamos/software1/backend/
```

Ignore it.

Do NOT modify backend routes/controllers/models/migrations under:

```text
software1/backend/
```

unless explicitly requested.

The real backend is:

```text
backend/
```

Database restore script:

```text
scripts/restore_local_db.sh
```

Root `node_modules/` is legacy/leftover.

Real backend dependencies belong under:

```text
backend/node_modules/
```

---

# Database rules

Development uses the intended local PostgreSQL database.

Typical name:

```text
appprestamos_local
```

Never point local QA at production.

Do not restore the database simply because the program needs to run.

Only restore when genuinely required and explicitly appropriate.

Restore command when actually needed:

```bash
./scripts/restore_local_db.sh "/absolute/path/to/appprestamos-backup.dump"
```

The restore tooling is designed to reject suspicious remote/production-looking targets.

Backend boot may execute:

```text
ensureRuntimeDBTuning()
```

which can perform local idempotent database adjustments.

Therefore the backend must use the intended local DB.

---

# Backend commands

From:

```text
backend/
```

Install dependencies:

```bash
npm ci
```

Start:

```bash
npm start
```

Development/watch:

```bash
npm run dev
```

Direct entrypoint:

```bash
node index.js
```

Check:

```bash
npm run check
```

Tests:

```bash
npm test
```

Known historical backend test count:

```text
20
```

The exact test count is not an invariant if legitimate tests are added or removed.

---

# Flutter commands

From:

```text
software1/
```

Dependencies:

```bash
flutter pub get
```

Formatting check:

```bash
dart format --output=none --set-exit-if-changed lib test
```

Static analysis:

```bash
flutter analyze
```

Tests:

```bash
flutter test
```

Web tests:

```bash
flutter test --platform chrome
```

Canonical remote run:

```bash
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 7357 \
  --dart-define=API_BASE_URL=https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

---

# Local-only Mac browser development

For Mac-only browser development, localhost can be used.

Example:

```bash
flutter run -d chrome \
  --web-port 7357 \
  --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

This is NOT the canonical physical-iPhone workflow.

Do not replace the remote configuration with this merely because it works on the Mac.

---

# LAN fallback

Direct Mac LAN-IP access is only a fallback/debugging mode.

It is NOT canonical.

LAN mode may require:

- Mac and iPhone on same LAN
- firewall access
- LAN bind configuration
- LAN origin in CORS
- LAN backend API URL

Do not replace the Tailscale Serve workflow with LAN mode unless explicitly requested.

---

# Generated Flutter build directory

`software1/build` is generated output.

It must not be committed.

It must not remain linked to an OpenCode temporary path.

Bad example:

```text
software1/build -> /private/var/.../T/opencode/...
```

This can happen when temporary tooling is copied through a backup.

If a broken OpenCode-temp symlink is found, remove ONLY that symlink and recreate a normal build directory.

Do not treat a temporary build symlink as project source state.

---

# Authentication facts

Login route:

```text
POST /login
```

Auth routes are mounted from the real backend.

JWT payload expects values including:

- `id`
- `role`
- `name`
- `email`

Known roles:

- `admin`
- `cliente`

Login/register normalize email to lowercase.

Registration creates normal client accounts according to existing behavior.

Admin accounts are created/seeded separately.

Do not silently modify authentication contracts during unrelated work.

---

# Security and environment constraints

Never commit:

- `.env`
- database dumps
- backups
- secrets
- JWT secrets
- SMTP credentials
- API keys
- `node_modules`
- generated build output
- broken build symlinks
- `.DS_Store`

Never expose PostgreSQL port `5432`.

Keep optional outbound integrations disabled during ordinary local QA unless explicitly needed.

Examples:

- SMTP
- SendGrid
- FCM
- Cloudinary

Typical local QA:

```text
EMAIL_OUTBOX_DISABLED=1
```

Do not add real cloud credentials merely to make tests pass.

Do not weaken production diagnostics/security for local convenience.

---

# Files and document storage facts

Photos, signatures, documents, and receipts may be stored in PostgreSQL through:

- `BYTEA`
- base64

Do not assume they are ordinary filesystem files.

Profile upload handling under:

```text
/uploads/profiles
```

is a notable filesystem exception.

Inspect existing implementation before changing storage strategy.

---

# Testing reality

Backend tests cover areas including:

- authentication
- roles
- receipts
- documents
- idempotency
- optional email failure behavior

Flutter tests cover areas including:

- auth sessions
- valid/expired JWT behavior
- login/widget behavior
- preference cleanup

Automated tests are NOT a substitute for the real physical-iPhone remote workflow.

There is no automated test that proves all of:

1. Safari opens frontend
2. frontend reaches remote backend
3. browser CORS succeeds
4. login succeeds on physical iPhone

---

# Required checks before committing code changes

Run checks relevant to the changed scope.

Backend:

```bash
npm run check
npm test
```

Flutter:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Git:

```bash
git diff --check
git status --short
git diff
```

Review before staging.

Do not stage unrelated generated/dependency changes.

Do not automatically commit unless explicitly requested.

---

# Git safety

The repository can contain substantial legitimate uncommitted work.

A dirty working tree is normal until proven otherwise.

Do NOT use destructive cleanup to make tests or tooling easier.

Do NOT assume deleted/tracked `node_modules` entries are application source changes.

Do NOT restore all files to HEAD merely to get a clean state.

Always understand the requested task and the existing working state first.

---

# Process safety

A listener on a canonical port is not automatically the correct process.

Always verify:

- PID
- command
- cwd

A stale Flutter process may be running from a backup/rollback directory.

A stale backend may also survive a previous development session.

Reuse healthy canonical instances.

Gracefully stop stale instances.

Never kill processes globally by generic executable name.

Avoid commands such as broad:

```text
killall node
killall dart
killall flutter
pkill node
pkill dart
```

because other projects/tools may use those processes.

Use port/PID/cwd-specific process management.

---

# Runtime success criteria

For normal RUN, server-side success means all of the following:

## Backend local

```text
http://127.0.0.1:3000/db-health
```

returns healthy JSON.

## Backend Tailscale

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:3001/db-health
```

returns healthy JSON.

## Login preflight

`OPTIONS /login` from Origin:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

returns:

```text
Access-Control-Allow-Origin: https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

## Flutter local

```text
http://127.0.0.1:7357
```

is reachable.

## Flutter Tailscale

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

is reachable.

## API build target

Flutter remote instance uses:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

as `API_BASE_URL`.

Only then report server-side RUN success.

---

# Runtime final report

After RUN, provide a concise operational report.

Include:

- repo root
- branch
- backend status
- backend PID if useful
- frontend status
- frontend PID if useful
- Tailscale backend mapping
- Tailscale frontend mapping
- local backend health
- remote backend health
- login CORS status
- local frontend status
- remote frontend status
- files changed during runtime repair
- whether physical iPhone login is confirmed or awaiting user test

End with the iPhone URL:

```text
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Do not flood the user with irrelevant logs when everything works.

---

# Gotchas agents commonly miss

The real Git root is `AppPrestamos`, not its parent.

`backend/index.js` is the real backend entrypoint.

`software1/backend` is residual.

Dirty Git state does not mean reset.

A frontend HTTP 200 does not prove login works.

A backend `/db-health` 200 does not prove CORS works.

A CORS OPTIONS `200` without `Access-Control-Allow-Origin` does not prove CORS works.

Mac browser success does not prove iPhone Safari success.

A stale process may be serving from a backup directory.

A copied `software1/build` symlink may point to a deleted OpenCode temp directory.

Closing terminals and later restarting the backend causes `.env` to be read again, so canonical CORS must be persisted in `.env`, not supplied only as a one-time shell environment variable.

Do NOT "fix" persistent CORS only with:

```bash
CORS_ORIGINS='...' node index.js
```

when the canonical `.env` value itself is wrong.

The permanent local development setting must be correct so future RUN commands work after terminals are closed.

---

# Android notes

Android work is separate from the canonical Safari remote-development workflow.

Historical tooling issues include:

- JDK / Gradle compatibility
- Android SDK requirements

Do not modify or break the known-good web/iPhone runtime while doing unrelated Android work.

---

# Operational principle

Preserve known-good infrastructure.

When the user says RUN, actually run the complete known-good setup.

When the user says STOP, stop only the relevant AppPrestamos processes safely.

When the user says RESTART, safely stop and fully run again.

When the user says STATUS, inspect without changing state.

Self-heal known safe runtime issues instead of merely reporting them.

Do not make the user repeatedly repair CORS, ports, stale processes, Tailscale mappings, or broken temporary build symlinks when those repairs are explicitly defined here.

Change the smallest possible scope.

Inspect before killing.

Inspect before editing environment configuration.

Preserve secrets.

Preserve Tailscale mappings.

Preserve PostgreSQL privacy.

Preserve legitimate uncommitted work.

Verify real behavior, not only tests.
