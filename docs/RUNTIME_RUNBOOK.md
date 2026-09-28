# AppPrestamos — canonical runtime runbook

Effective 2026-09-27. Read AGENTS.md first and this entire guide before runtime work.
This consolidates the previous operational instructions without changing the architecture.
The original is retained in `archive/AGENTS-before-2026-09-19.md` as historical reference only.
READ-ONLY for OpenCode executors. Only the user/supervisor maintains this guide.
RUN/STOP/RESTART permits its listed runtime actions, not rewriting this guide or other protected instructions.

## Intent and authority

An explicit RUN/START/LAUNCH, STOP/TERMINATE, RESTART/RERUN or OPENCODE REMOTE request directly authorizes its procedure.
Spanish equivalents include `levanta/corre/inicia/pon el programa a correr`, `para/detén/apaga/cierra el programa`,
and `reinicia/vuelve a correrlo`. No second plan approval is needed for the established operations below.
Interpret context: asking to run tests or quoting these words does not start the application.
STATUS (`is it running?`, `está corriendo?`, `check status`) is strictly read-only.
If asked for only frontend/backend, act only on that component; report missing dependencies without changing them.

RUN means the complete canonical remote setup, left running. Compilation or frontend HTTP 200 alone is insufficient.
STOP means only the application's backend/frontend processes, not Tailscale, PostgreSQL, OpenCode or unrelated processes.
RESTART means safe STOP followed by complete RUN, not destructive cleanup.

OpenCode Remote is a separate operational target. Phrases such as `Run OpenCode Remote`, `start/launch OpenCode remote`,
or `inicia/activa/levanta/abre/pon OpenCode remoto a correr` authorize the OpenCode Remote procedure below, not the
AppPrestamos RUN procedure. `status/revisa OpenCode remoto` is read-only. `stop/para/detén/apaga OpenCode remoto`
stops only that service. A generic AppPrestamos STOP must continue to preserve OpenCode.

## Canonical topology — preserve it

Repository: `/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos`

| Component | Local target | Tailscale HTTPS endpoint |
| --- | --- | --- |
| Flutter `software1/` | `0.0.0.0:7357`, proxy target `http://127.0.0.1:7357` | `https://johans-macbook-pro.tailfbc2ea.ts.net:7358` |
| Express `backend/index.js` | `http://127.0.0.1:3000` | `https://johans-macbook-pro.tailfbc2ea.ts.net:3001` |
| PostgreSQL | Existing local database, normally `appprestamos_local` | NONE; never expose `5432` |

The physical iPhone opens the frontend HTTPS URL; Flutter calls the backend HTTPS URL; only the backend accesses PostgreSQL.
Never publish PostgreSQL via Serve, Funnel, LAN/public bindings or port forwarding.
Preserve existing backend binding and the canonical Flutter API build target. Do not substitute direct Tailscale-IP/LAN HTTP.

Other mappings may include OpenCode at `https://johans-macbook-pro.tailfbc2ea.ts.net` → `http://127.0.0.1:49374`
and diagnostics `:7364` → `:7363`. Preserve them even if their target is currently offline.
Never use a blanket Tailscale Serve reset.

## OpenCode Remote procedure

This procedure was verified against the installed OpenCode CLI on 2026-09-27. Its canonical private topology is:

```text
OpenCode background service: http://127.0.0.1:49374
Tailnet-only endpoint:        https://johans-macbook-pro.tailfbc2ea.ts.net
Tailscale target:             http://127.0.0.1:49374
```

It does not expose OpenCode publicly: use Tailscale Serve, never Funnel. It does not require AppPrestamos backend,
Flutter or PostgreSQL to be running.

### RUN / START OpenCode Remote

1. Read the current service configuration and state without printing credentials:

```bash
opencode service get
opencode service status
lsof -nP -iTCP:49374 -sTCP:LISTEN
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
```

Do NOT run `opencode pair` in agent output: it prints the pairing password and QR code. Never copy OpenCode credentials
into chat, logs, tasks, reports or versioned files.

2. The required service configuration is `hostname=127.0.0.1` and `port=49374`. If either differs, this explicit
OpenCode Remote RUN authorizes correcting only those two keys, then restarting the service:

```bash
opencode service set hostname 127.0.0.1
opencode service set port 49374
opencode service restart
```

If the configuration is already correct but the service/listener is absent, start it:

```bash
opencode service start
```

Reuse a healthy existing service; do not start a duplicate. Do not use `--hostname 0.0.0.0`: remote access is through
the loopback target plus Tailscale Serve. Do not change providers, models, credentials, permissions or OpenCode config.

3. Preserve every existing Tailscale mapping. If and only if the root OpenCode mapping is missing or points somewhere
other than `http://127.0.0.1:49374`, repair that mapping alone:

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg http://127.0.0.1:49374
```

Never run `tailscale serve reset`. Do not disturb AppPrestamos `:3001`/`:7358` or diagnostics `:7364`.

4. Verify the final state without revealing response bodies or authentication material:

```bash
opencode service get
opencode service status
lsof -nP -iTCP:49374 -sTCP:LISTEN
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
curl --silent --show-error --output /dev/null --write-out '%{http_code}\n' \
  --connect-timeout 5 --max-time 20 https://johans-macbook-pro.tailfbc2ea.ts.net
```

Report the URL, service/listener/mapping status and HTTP status only. A protected/authentication response still proves
reachability; do not weaken or remove authentication to obtain HTTP 200.

### STATUS / STOP OpenCode Remote

STATUS performs only steps 1 and 4 without repair. STOP first confirms that the service/listener is OpenCode, then runs:

```bash
opencode service stop
```

Verify that `:49374` no longer listens. Preserve the root Tailscale mapping so a later RUN can reuse it, and do not stop
AppPrestamos, PostgreSQL, Tailscale itself, or unrelated processes. RESTART OPENCODE REMOTE means this narrow STOP followed
by its narrow RUN procedure.

## Narrowly authorized self-healing during RUN/RESTART

Do the following when necessary instead of merely telling the user to fix them:

- Add the exact canonical frontend origin to persistent `CORS_ORIGINS`, preserving all existing valid origins.
- Recreate a missing canonical frontend/backend Serve mapping without disturbing other mappings.
- Gracefully stop a positively identified stale AppPrestamos process from a backup/rollback checkout that blocks a canonical port.
- Restart the canonical backend to reload its corrected `.env`, and restart canonical Flutter when necessary.
- Remove ONLY a broken `software1/build` symlink whose target is an OpenCode temporary directory; recreate a normal build directory.
- Run `flutter pub get` if packages need preparation; `npm ci` only if backend dependencies are genuinely missing.
- Start the already-installed intended local PostgreSQL service if clearly stopped and needed; inspect its service/cluster first.

These permissions do NOT authorize database restoration/deletion, new databases/users, replacement of `.env`, secret rotation,
business-logic edits, migrations, Git resets, port changes, unrelated process termination, toolchain installation,
unrelated Serve mapping changes, real outbound notifications, or PostgreSQL exposure.
If a larger change or unavailable permission is needed, report the blocker. Do not invent another runtime architecture.

`scripts/dev/dev_remote_start.sh` and `scripts/dev/dev_remote_restart.sh` have not been reconciled with this runbook.
Do not execute them: they contain broad process matching and conflicting direct-IP behavior.

## RUN / START procedure

### 1. Verify repository and read state

```bash
cd /Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos
pwd
git rev-parse --show-toplevel
git branch --show-current
git status --short
```

The Git top-level must exactly match this checkout. Expected branch: `codex/resume-local-dev`.
Never clean the dirty tree; substantial legitimate application work may be uncommitted.

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
lsof -nP -iTCP:3000 -sTCP:LISTEN
lsof -nP -iTCP:7357 -sTCP:LISTEN
```

An empty listener result is not a reason to kill other processes. If sandbox/network permissions prevent a check,
record that as unavailable, not as evidence the service is stopped or broken.

### 2. Identify each existing listener before action

For each actual PID discovered above (replace `<PID>` with that verified number):

```bash
ps -p <PID> -o pid,ppid,lstart,command=
lsof -a -p <PID> -d cwd
```

Reuse healthy canonical instances. Check both cwd and command; the port alone is not identity.
For Flutter, also verify that the launch arguments use the canonical remote API URL.
If a stale AppPrestamos process from `_BACKUP_`, `_BEFORE_ROLLBACK_`, `_FAILED_`, or another AppPrestamos copy
blocks a canonical port, terminate only that identified process gracefully as in STOP, then verify the port.
If the owner is unrelated or identity is uncertain, ask rather than killing it or changing canonical ports.
Never broad `pkill`, `killall`, or generic process-name termination. Do not start duplicate servers.

### 3. Ensure persistent CORS, without revealing secrets

From the repository root, inspect ONLY:

```bash
grep '^CORS_ORIGINS=' backend/.env || true
```

Required development origins:

```text
http://localhost:7357
http://127.0.0.1:7357
https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

An existing fallback such as `http://100.88.95.23:7357` may remain. Preserve valid existing origins.
If the canonical origin is missing, edit ONLY the `CORS_ORIGINS` assignment; no duplicates and no wildcard `*`.
Example of the minimum canonical value:

```text
CORS_ORIGINS=http://localhost:7357,http://127.0.0.1:7357,https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Verify only that setting afterwards with the same grep, then reload the backend if changed.
Do not print the full `.env`, DATABASE_URL, JWT_SECRET, SMTP credentials, keys, or other secrets.
Do not replace `.env`. If it is missing or its intended local DB target is uncertain, stop and request setup direction.
Inspect only the minimum nonsecret DB host/name metadata if needed to establish the local target.
Do not claim a one-off `CORS_ORIGINS=... node index.js` environment override is a persistent fix.

### 4. Validate generated Flutter build directory

```bash
ls -ld software1/build 2>&1
file software1/build 2>&1
readlink software1/build 2>&1 || true
```

The canonical build path should be absent or a normal generated directory, not an OpenCode-temp link.
Only if `software1/build` is a symlink, its target is missing, and it points into an OpenCode temporary directory
(for example `/private/var/.../T/opencode/...`), remove that exact link and create a normal directory:

```bash
rm software1/build
mkdir -p software1/build
```

This is not permission to remove a directory, a valid unrelated symlink, or other build paths.
If another symlink arrangement exists, inspect and ask rather than redesigning the build strategy.
Do not commit generated build output or recreate historical temporary build links.

### 5. Start/reload the real backend if necessary

Use a managed/background shell that keeps it running; preserve unrelated processes.

```bash
cd /Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos/backend
npm start
```

Equivalent entrypoint: `node index.js`. Never start `software1/backend`.
If CORS changed, gracefully stop only the verified canonical backend and restart it so `.env` reloads.
No automatic reinstall when dependencies are already present; `npm ci` is a missing-dependency repair, not a routine cleanup.
If the intended installed PostgreSQL service is stopped, start that service without exposing it or restoring anything.

Backend boot currently runs `ensureRuntimeDBTuning()`, which can normalize user data and adjust schema/indexes.
Normal RUN authorizes this existing canonical boot, not new tuning logic or bulk migration execution.
Never point QA at production. Keep optional outbound integrations disabled; disabling the outbox alone may not block direct SMTP.

### 6. Verify local backend, then remote backend

```bash
curl --fail --connect-timeout 5 --max-time 15 http://127.0.0.1:3000/db-health
```

Require successful HTTP and JSON containing `"ok":true`. If local health fails, diagnose backend/DB first.
Verify the backend Serve mapping is `:3001` → `http://127.0.0.1:3000`.
If missing, add ONLY that mapping:

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https=3001 http://127.0.0.1:3000
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
curl --fail --connect-timeout 5 --max-time 20 https://johans-macbook-pro.tailfbc2ea.ts.net:3001/db-health
```

Do not overwrite an unexpected existing mapping without understanding its ownership; report the conflict.
Remote health must also show `"ok":true`. Local success alone does not prove remote readiness.

### 7. Verify the login CORS preflight

```bash
APPPRESTAMOS_ORIGIN='https://johans-macbook-pro.tailfbc2ea.ts.net:7358'
APPPRESTAMOS_API='https://johans-macbook-pro.tailfbc2ea.ts.net:3001'
curl --fail -i --connect-timeout 5 --max-time 20 -X OPTIONS \
  -H "Origin: $APPPRESTAMOS_ORIGIN" \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type' \
  "$APPPRESTAMOS_API/login"
```

Require a successful preflight (normally 200/204) and this exact origin allowance:

```text
Access-Control-Allow-Origin: https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

The allowed method/headers must also permit POST and content-type. Header names are case-insensitive.
A 200 without the correct origin header is NOT success. If needed, repair only persistent CORS, restart
the canonical backend, and rerun the preflight. Do not knowingly report remote RUN success with broken login CORS.
This checks browser permission to send login, not whether credentials succeed.

### 8. Prepare and start Flutter if necessary

From the canonical frontend, prepare packages when needed:

```bash
cd /Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos/software1
flutter pub get
```

Reuse a healthy canonical instance with the correct API build target. Otherwise start and keep running:

```bash
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 7357 \
  --dart-define=API_BASE_URL=https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

Do not use `http://127.0.0.1:3000`, `http://100.88.95.23:3000`, or a LAN IP for this physical-iPhone instance.
Do not start another instance on an alternate port to evade a conflicting process.

### 9. Ensure frontend Serve mapping and verify both paths

Verify `:7358` → `http://127.0.0.1:7357`. If missing, add ONLY this mapping:

```bash
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https=7358 http://127.0.0.1:7357
TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
```

```bash
curl --fail -I --connect-timeout 5 --max-time 20 http://127.0.0.1:7357
curl --fail -I --connect-timeout 5 --max-time 20 https://johans-macbook-pro.tailfbc2ea.ts.net:7358
```

Both must reach the intended Flutter application, not merely an arbitrary listener.
If HEAD is inconclusive, inspect a bounded GET without exposing private app data.
Do not infer successful rendering or login from these checks alone.

### 10. Leave running and report

Report concisely: canonical root/branch; backend/frontend status and verified PIDs if useful;
both Serve mappings; local/remote backend health; login CORS; local/remote frontend reachability;
API build target; any files changed by permitted repairs; blockers and device-validation boundary.

On success, say “Server-side remote workflow verified. Physical iPhone login awaits user validation.”
Only say physical login is confirmed when the user actually confirms it for the relevant version.
Leave backend, Flutter, Tailscale and the local DB running. End with:

```text
iPhone Safari: https://johans-macbook-pro.tailfbc2ea.ts.net:7358
Backend: https://johans-macbook-pro.tailfbc2ea.ts.net:3001
```

## STOP procedure

1. Inspect `lsof -nP -iTCP:3000 -sTCP:LISTEN` and `lsof -nP -iTCP:7357 -sTCP:LISTEN`.
2. For each listener, inspect `ps -p <PID> -o pid,ppid,lstart,command=` and `lsof -a -p <PID> -d cwd`.
3. Only for the positively identified AppPrestamos process, issue `kill -TERM <PID>`.
4. Wait briefly and recheck both ports. Flutter may have a parent/child relationship; inspect exact related PIDs
   if the listener survives. Never kill all Dart/Flutter/Node processes.
5. Forced termination is a last resort only after graceful termination failed and the exact target identity is confirmed.
6. Verify no targeted canonical listener remains; report what was stopped or why it could not be stopped.

Normal STOP ends there. Preserve PostgreSQL, Tailscale, Serve mappings, OpenCode and unrelated processes.
Do not delete files, edit environment configuration, clean Git, or remove mappings just because their targets are offline.

## RESTART procedure

Safe STOP → verify canonical ports are free → complete RUN → revalidate remote login readiness.
No destructive cleanup between the two phases. Preserve DB and unrelated runtime/network state.

## STATUS procedure

Read-only: verify repository/branch, listener PID/command/cwd, API build argument, Serve mappings,
local/remote backend health, local/remote frontend reachability and login preflight using the checks above.
Do not start servers just to inspect them or import backend code as a health check.
No repairs, restarts, environment edits or DB changes. Report unhealthy/unavailable checks separately.

## Failure classification and debugging order

- Safari cannot open the page: inspect frontend listener, stale cwd, URL, Tailscale connectivity and Serve mapping.
  Do not immediately blame Flutter rendering.
- Page loads but is blank: reachability succeeded; inspect JS/runtime errors, assets, renderer, service worker and web compatibility.
- Page loads but login reports connection error: verify canonical API build target, backend `:3001`, CORS and OPTIONS,
  then actual POST `/login` status/body/content-type and app error handling. Do not redesign networking first.
- If all server-side readiness checks pass but physical login fails: inspect the real login request/backend logs safely,
  authentication response and Safari-specific behavior. Use approved existing accounts; redact passwords/tokens.

Order: frontend reachability → backend reachability → API_BASE_URL → CORS preflight → POST `/login` → application/auth behavior.
Persistent `.env` CORS matters because opening a new terminal/restarting rereads the file.

## Explicit alternate-platform work, not normal RUN

Mac-only Chrome can use localhost when explicitly requested:

```bash
flutter run -d chrome --web-port 7357 --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Do not replace a running physical-iPhone instance with this without permission; it shares the canonical port.
LAN access is only a requested fallback/debugging mode and can require firewall/CORS/binding changes.
iOS simulator/native and Android work are separate tasks. Do not change JDK/Gradle, signing, ATS, build-directory
strategy or known-good web/iPhone runtime merely to make a native build pass.
The historical LOCAL_DEVELOPMENT guide contains reference commands, not authorization to install/restore/reconfigure.

Restore tooling exists at `scripts/restore_local_db.sh`; restoration always needs specific approval and is not RUN.
Historical migrations may be non-idempotent/incomplete. Do not execute them as a generic repair.
