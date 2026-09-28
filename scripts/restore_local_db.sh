#!/usr/bin/env bash

# Restore an AppPrestamos PostgreSQL archive into a brand-new local database.
# Existing databases are never modified or removed by this script.

set -Eeuo pipefail
IFS=$'\n\t'

readonly DEFAULT_DB_NAME='appprestamos_local'
readonly DEFAULT_MAINTENANCE_DB='postgres'
database_created=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/restore_local_db.sh /absolute/path/to/backup.dump
  APPPRESTAMOS_DUMP_PATH=/absolute/path/to/backup.dump scripts/restore_local_db.sh

Optional environment variables:
  APPPRESTAMOS_DB_NAME          Target database (default: appprestamos_local).
                                Must begin with "appprestamos_".
  APPPRESTAMOS_PG_BIN           Directory containing PostgreSQL 18 tools.
  APPPRESTAMOS_MAINTENANCE_DB   Maintenance database (default: postgres).
  PGHOST, PGPORT, PGUSER        Standard libpq local connection settings.

Safety guarantees:
  - Only local PostgreSQL hosts or Unix sockets are accepted.
  - An existing target database is never restored over or deleted.
  - The archive is restored with --no-owner and --no-privileges.
  - Validation prints table names and aggregate row counts, never row data.
USAGE
}

log() {
  printf '[restore-local-db] %s\n' "$*"
}

die() {
  printf '[restore-local-db] ERROR: %s\n' "$*" >&2
  exit 1
}

report_failed_restore() {
  local exit_code=$?

  if (( database_created == 1 )); then
    printf "[restore-local-db] ERROR: Restore did not complete. Database '%s' was left in place and was not deleted.\n" "$db_name" >&2
  fi
  exit "$exit_code"
}

trap report_failed_restore ERR

if [[ ${1:-} == '--help' || ${1:-} == '-h' ]]; then
  usage
  exit 0
fi

if (( $# > 1 )); then
  usage >&2
  die 'Provide the dump path once, either as the first argument or APPPRESTAMOS_DUMP_PATH.'
fi

dump_path=${1:-${APPPRESTAMOS_DUMP_PATH:-}}
db_name=${APPPRESTAMOS_DB_NAME:-$DEFAULT_DB_NAME}
maintenance_db=${APPPRESTAMOS_MAINTENANCE_DB:-$DEFAULT_MAINTENANCE_DB}
pg_host=${PGHOST:-}
pg_port=${PGPORT:-5432}

[[ -n $dump_path ]] || die 'No dump path was provided. See --help.'
[[ -r $dump_path ]] || die "Dump is not readable: $dump_path"
[[ -f $dump_path || -d $dump_path ]] || die 'The dump path must be a regular archive file or a PostgreSQL directory archive.'

# The strict prefix prevents accidental selection of postgres, template databases,
# or a production database name. PostgreSQL identifiers are limited to 63 bytes.
if [[ ! $db_name =~ ^appprestamos_[a-z0-9_]+$ || ${#db_name} -gt 63 ]]; then
  die 'Unsafe database name. Use 63 or fewer lowercase letters, digits, or underscores beginning with appprestamos_.'
fi

case $db_name in
  *_prod|*_prod_*|*_production|*_production_*|*_render|*_render_*|*_remote|*_remote_*|*_live|*_live_*)
    die 'Refusing a database name that suggests a remote or production target.'
    ;;
esac

if [[ ! $maintenance_db =~ ^[A-Za-z_][A-Za-z0-9_]{0,62}$ ]]; then
  die 'Unsafe maintenance database name.'
fi

if [[ ! $pg_port =~ ^[0-9]+$ ]] || (( pg_port < 1 || pg_port > 65535 )); then
  die 'PGPORT must be a number between 1 and 65535.'
fi

case $pg_host in
  ''|localhost|127.0.0.1|::1|/*)
    ;;
  *)
    die 'Refusing a non-local PGHOST. Use localhost, 127.0.0.1, ::1, or a local Unix socket directory.'
    ;;
esac

case ${PGHOSTADDR:-} in
  ''|127.0.0.1|::1)
    ;;
  *)
    die 'Refusing a non-local PGHOSTADDR.'
    ;;
esac

[[ -z ${PGSERVICE:-} ]] || die 'PGSERVICE is not accepted because it could redirect the restore to a remote server.'

postgres_major() {
  "$1" --version 2>/dev/null | sed -E 's/.* ([0-9]+)(\.[0-9]+)*$/\1/'
}

valid_pg18_dir() {
  local candidate=$1
  local tool

  for tool in pg_restore psql createdb; do
    [[ -x $candidate/$tool ]] || return 1
    [[ $(postgres_major "$candidate/$tool") == '18' ]] || return 1
  done
}

find_pg18_bin() {
  local candidate
  local tool_dir
  local -a candidates=()

  if [[ -n ${APPPRESTAMOS_PG_BIN:-} ]]; then
    candidates+=("${APPPRESTAMOS_PG_BIN%/}")
  fi

  candidates+=(
    '/opt/homebrew/opt/postgresql@18/bin'
    '/usr/local/opt/postgresql@18/bin'
    '/opt/homebrew/opt/libpq/bin'
    '/usr/local/opt/libpq/bin'
  )

  if command -v pg_restore >/dev/null 2>&1; then
    tool_dir=$(dirname "$(command -v pg_restore)")
    candidates+=("$tool_dir")
  fi

  for candidate in "${candidates[@]}"; do
    if valid_pg18_dir "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

pg_bin=$(find_pg18_bin) || die 'PostgreSQL 18 client tools were not found. Install postgresql@18 or set APPPRESTAMOS_PG_BIN.'
readonly PG_RESTORE="$pg_bin/pg_restore"
readonly PSQL="$pg_bin/psql"
readonly CREATEDB="$pg_bin/createdb"

export PGAPPNAME='appprestamos_local_restore'
export PGCONNECT_TIMEOUT=${PGCONNECT_TIMEOUT:-5}

server_args=(--port="$pg_port")
if [[ -n $pg_host ]]; then
  server_args+=(--host="$pg_host")
fi
if [[ -n ${PGUSER:-} ]]; then
  server_args+=(--username="$PGUSER")
fi

log "Using PostgreSQL client tools from $pg_bin"
log 'Validating the archive format (no data is printed)...'
"$PG_RESTORE" --list "$dump_path" >/dev/null

log 'Checking the local PostgreSQL server...'
server_version_num=$(
  "$PSQL" -X "${server_args[@]}" --dbname="$maintenance_db" \
    --set=ON_ERROR_STOP=1 --tuples-only --no-align \
    --command='SHOW server_version_num;'
)
server_version_num=${server_version_num//[[:space:]]/}

if [[ ! $server_version_num =~ ^[0-9]+$ ]] || (( server_version_num < 180000 || server_version_num >= 190000 )); then
  die "The local server must be PostgreSQL 18; reported server_version_num=$server_version_num."
fi

database_exists=$(
  "$PSQL" -X "${server_args[@]}" --dbname="$maintenance_db" \
    --set=ON_ERROR_STOP=1 --tuples-only --no-align \
    --command="SELECT 1 FROM pg_database WHERE datname = '$db_name';"
)
database_exists=${database_exists//[[:space:]]/}

if [[ $database_exists == '1' ]]; then
  die "Database '$db_name' already exists. It was not modified. Choose another APPPRESTAMOS_DB_NAME or inspect it manually."
fi

log "Creating new local database '$db_name'..."
"$CREATEDB" "${server_args[@]}" --maintenance-db="$maintenance_db" \
  --encoding=UTF8 --template=template0 "$db_name"
database_created=1

log 'Restoring schema and data in one transaction...'
# A new PostgreSQL database already contains the public schema. --clean removes
# only objects in the database that this script just created; the existence check
# and createdb result above prevent this command from targeting an existing DB.
"$PG_RESTORE" "${server_args[@]}" --dbname="$db_name" \
  --exit-on-error --single-transaction --clean --if-exists \
  --no-owner --no-privileges "$dump_path"

expected_tables=(
  device_tokens
  email_outbox
  loan_installment_logs
  loan_installments
  loan_options
  loan_requests
  news
  notifications
  settings
  suggestions
  user_documents
  users
)

expected_values=''
for table_name in "${expected_tables[@]}"; do
  if [[ -n $expected_values ]]; then
    expected_values+=','
  fi
  expected_values+="('$table_name')"
done

missing_tables=$(
  "$PSQL" -X "${server_args[@]}" --dbname="$db_name" \
    --set=ON_ERROR_STOP=1 --tuples-only --no-align \
    --command="WITH expected(name) AS (VALUES $expected_values)
               SELECT expected.name
               FROM expected
               LEFT JOIN information_schema.tables AS actual
                 ON actual.table_schema = 'public'
                AND actual.table_type = 'BASE TABLE'
                AND actual.table_name = expected.name
               WHERE actual.table_name IS NULL
               ORDER BY expected.name;"
)

if [[ -n $missing_tables ]]; then
  printf '[restore-local-db] Missing expected tables:\n%s\n' "$missing_tables" >&2
  die 'Restore validation failed. The database was left in place for inspection and was not deleted.'
fi

log 'Expected tables are present. Aggregate row counts:'
"$PSQL" -X "${server_args[@]}" --dbname="$db_name" \
  --set=ON_ERROR_STOP=1 --pset=pager=off --pset=footer=off \
  --command="SELECT 'device_tokens' AS table_name, count(*)::bigint AS row_count FROM public.device_tokens
             UNION ALL SELECT 'email_outbox', count(*)::bigint FROM public.email_outbox
             UNION ALL SELECT 'loan_installment_logs', count(*)::bigint FROM public.loan_installment_logs
             UNION ALL SELECT 'loan_installments', count(*)::bigint FROM public.loan_installments
             UNION ALL SELECT 'loan_options', count(*)::bigint FROM public.loan_options
             UNION ALL SELECT 'loan_requests', count(*)::bigint FROM public.loan_requests
             UNION ALL SELECT 'news', count(*)::bigint FROM public.news
             UNION ALL SELECT 'notifications', count(*)::bigint FROM public.notifications
             UNION ALL SELECT 'settings', count(*)::bigint FROM public.settings
             UNION ALL SELECT 'suggestions', count(*)::bigint FROM public.suggestions
             UNION ALL SELECT 'user_documents', count(*)::bigint FROM public.user_documents
             UNION ALL SELECT 'users', count(*)::bigint FROM public.users
             ORDER BY table_name;"

log "Restore and validation completed for '$db_name'."
trap - ERR
