# Desarrollo local de AppPrestamos — referencia histórica y modos alternativos

> Guía histórica; aviso actualizado el 2026-09-19. Para RUN/STOP/RESTART/STATUS usa exclusivamente
> [RUNTIME_RUNBOOK.md](RUNTIME_RUNBOOK.md) y [AGENTS.md](../AGENTS.md).
> Los pasos de instalación, restauración, LAN y plataformas nativas de este archivo NO forman parte del arranque normal
> ni autorizan reemplazar la configuración Tailscale HTTPS. Conservamos esta información como referencia.
> Reutiliza la base y cuentas existentes; no ejecutes aquí una restauración ni crees otra base sin permiso específico.

Esta guía levanta una copia local aislada de PostgreSQL y el backend, y después ejecuta Flutter en Chrome, el simulador de iOS o un iPhone dentro de la red local. La vista web es útil para iterar rápido, pero no sustituye las pruebas nativas de permisos, archivos, teclado, Safe Area y apertura de documentos.

## Reglas de seguridad

- Trata cualquier dump como material sensible. No lo copies dentro del repositorio, no lo envíes por mensajería y no lo subas a almacenamiento público.
- No reutilices URLs, contraseñas, tokens ni claves del entorno suspendido. Usa secretos nuevos y exclusivos para desarrollo local.
- Nunca expongas PostgreSQL (`5432`) al iPhone ni a Internet. El teléfono solo debe comunicarse con el backend HTTP.
- Mantén correo, push, Cloudinary y otros servicios externos desactivados durante las pruebas locales, salvo que estés usando cuentas sandbox.
- El script de restauración se niega a tocar una base existente y solo admite un servidor PostgreSQL local.

## 1. Requisitos de macOS

Instala PostgreSQL 18 y verifica que tanto cliente como servidor sean versión 18:

```bash
brew install postgresql@18
export PATH="$(brew --prefix postgresql@18)/bin:$PATH"
brew services start postgresql@18
psql --version
pg_restore --version
psql postgres -Atc 'SHOW server_version;'
```

Si prefieres controlar el servidor manualmente en vez de usar `brew services`, usa el mismo clúster local con `pg_ctl` (elige un solo método de arranque):

```bash
export APPPRESTAMOS_PGDATA="$(brew --prefix)/var/postgresql@18"
pg_ctl -D "$APPPRESTAMOS_PGDATA" status || pg_ctl -D "$APPPRESTAMOS_PGDATA" start
```

También necesitas Node.js/npm, Flutter, Xcode y CocoaPods. Comprueba el entorno móvil con:

```bash
flutter doctor -v
pod --version
```

## 2. Restaurar el backup en una base nueva

Desde la raíz del repositorio, entrega la ruta absoluta del dump custom como argumento:

```bash
./scripts/restore_local_db.sh "/absolute/path/to/appprestamos-backup.dump"
```

También puedes usar una variable de entorno:

```bash
export APPPRESTAMOS_DUMP_PATH="/absolute/path/to/appprestamos-backup.dump"
./scripts/restore_local_db.sh
unset APPPRESTAMOS_DUMP_PATH
```

El nombre predeterminado es `appprestamos_local`. Para crear otra copia aislada:

```bash
APPPRESTAMOS_DB_NAME=appprestamos_local_test ./scripts/restore_local_db.sh "/absolute/path/to/appprestamos-backup.dump"
```

El script:

1. exige herramientas cliente y servidor PostgreSQL 18;
2. rechaza hosts remotos y nombres de base peligrosos;
3. valida el archivo mediante `pg_restore --list`;
4. se detiene si la base destino ya existe;
5. crea la base desde `template0`;
6. restaura en una sola transacción con `--no-owner --no-privileges`;
7. comprueba las tablas esperadas;
8. muestra únicamente conteos agregados, nunca filas.

Una segunda ejecución con el mismo nombre se detendrá sin modificar la base existente. El script tampoco elimina automáticamente una base si la restauración falla; esto evita borrar algo sin una revisión humana.

Variables opcionales:

- `APPPRESTAMOS_DB_NAME`: base destino; debe comenzar por `appprestamos_`.
- `APPPRESTAMOS_PG_BIN`: carpeta de binarios de PostgreSQL 18.
- `APPPRESTAMOS_MAINTENANCE_DB`: base de mantenimiento; por defecto `postgres`.
- `PGHOST`, `PGPORT` y `PGUSER`: opciones estándar de libpq. `PGHOST` solo puede ser local o un socket Unix.

No ejecutes las migraciones históricas encima de este dump: el archivo ya contiene el esquema completo y varias migraciones antiguas no son idempotentes.

## 3. Configurar y levantar el backend

El backend lee `backend/.env`. Crea un archivo exclusivamente local y asegúrate de que no quede staged en Git. Debe configurar, como mínimo:

- `DATABASE_URL` para `appprestamos_local` en la instancia local;
- `DB_SSL_DISABLED=1`, porque PostgreSQL local normalmente no usa el SSL de Render;
- un `JWT_SECRET` nuevo, aleatorio y exclusivo de desarrollo;
- `PORT=3000`;
- `CORS_ORIGINS` con los orígenes web exactos que usarás, inicialmente `http://localhost:7357` y `http://127.0.0.1:7357`;
- `EMAIL_OUTBOX_DISABLED=1`.

Deja sin configurar SMTP, SendGrid, FCM y Cloudinary durante las pruebas iniciales. No copies valores del antiguo `.env`.

Instala dependencias y ejecuta la API:

```bash
cd backend
npm ci
npm start
```

En otra terminal, comprueba solo endpoints de salud:

```bash
curl --fail http://127.0.0.1:3000/
curl --fail http://127.0.0.1:3000/db-health
```

El arranque del backend ejecuta algunos ajustes idempotentes de esquema y normalización. Haz las primeras pruebas únicamente contra la copia local restaurada.

## 4. Flutter Web en el Mac

Desde `software1`:

```bash
flutter pub get
flutter run -d chrome \
  --web-port 7357 \
  --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Antes de probar flujos completos, verifica login, navegación, subida y apertura de documentos, recibos y manejo de errores. Revisa la consola del navegador y la terminal del backend en paralelo.

## 5. Simulador de iOS

El simulador comparte la red del Mac, por lo que puede usar `127.0.0.1`:

```bash
open -a Simulator
flutter devices
flutter run -d "<simulator-id>" \
  --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Si CocoaPods todavía no está preparado:

```bash
cd ios
pod install
cd ..
```

Configura en Xcode un Team de firma y un bundle identifier propio antes de una instalación nativa.

### Si `codesign` rechaza metadatos de Finder

En carpetas administradas por iCloud Drive o FileProvider, Xcode puede fallar con
`resource fork, Finder information, or similar detritus not allowed`. No limpies
atributos sobre el código fuente. Históricamente se usó salida fuera de la carpeta
sincronizada y un enlace temporal de `build`; esa estrategia NO es la configuración canónica actual.
No muevas el checkout ni recrees enlaces a `/private/tmp` como reparación automática.
Actualmente `software1/build` debe ser un directorio generado normal (o no existir aún).
La guía operativa permite reparar únicamente un enlace roto a un directorio temporal de OpenCode.
Si una tarea nativa necesita otra estrategia de salida, presenta el diagnóstico y pide aprobación.

## 6. Probar desde un iPhone por LAN

El iPhone no puede usar `localhost`: para el teléfono, `localhost` es el propio iPhone. El Mac y el iPhone deben estar en la misma Wi-Fi, sin aislamiento de clientes, VPN ni una red de invitados.

Obtén la IP privada del Mac, por ejemplo:

```bash
ipconfig getifaddr en0
```

Usa el valor devuelto como `MAC_LAN_IP` solo en tu terminal local. Primero comprueba que el backend responde por esa interfaz:

```bash
curl --fail "http://MAC_LAN_IP:3000/db-health"
```

Antes de reiniciar el backend para la prueba web en el teléfono, añade también `http://MAC_LAN_IP:7357` a `CORS_ORIGINS` en el `.env` local. No uses `*` como atajo.

Para abrir la versión web desde Safari en el iPhone:

```bash
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 7357 \
  --dart-define=API_BASE_URL=http://MAC_LAN_IP:3000
```

Abre `http://MAC_LAN_IP:7357` en el iPhone. Autoriza Node/Flutter en el firewall de macOS solo para redes privadas si macOS lo solicita.

Para la app nativa:

1. conecta el iPhone por cable, pulsa **Confiar** y activa Developer Mode;
2. abre `software1/ios/Runner.xcworkspace` en Xcode;
3. selecciona tu Team y un bundle identifier propio;
4. confirma que `flutter devices` enumera el iPhone;
5. ejecuta:

```bash
flutter run -d "<iphone-device-id>" \
  --dart-define=API_BASE_URL=http://MAC_LAN_IP:3000
```

El HTTP local puede requerir permisos de red local y una excepción ATS exclusiva de desarrollo en iOS. No habilites tráfico HTTP arbitrario en una compilación de distribución. Si no deseas una excepción de desarrollo, usa un túnel HTTPS autenticado hacia el backend y pasa esa URL como `API_BASE_URL`; no publiques PostgreSQL.

## 7. Comprobaciones antes de desarrollar

```bash
git status --short
cd software1
flutter analyze
flutter test
```

Confirma que no aparecen `.env`, dumps, backups, builds, `node_modules`, datos descargados ni archivos generados en `git status`. Si alguno aparece, no lo agregues al commit y revisa `.gitignore` antes de continuar.
