#!/usr/bin/env bash
# Idempotent, version-aware migration runner.
# Connection source order:
#   1. MYWEBAPP_DB_* env vars (container path, set by docker-compose)
#   2. TOML file at $MYWEBAPP_CONFIG (default /etc/mywebapp/config.toml; VM/systemd path)
# Each migration runs inside a single transaction — partial commits never happen.

set -euo pipefail

MIGRATIONS_DIR="${MIGRATIONS_DIR:-$(cd "$(dirname "$0")/.." && pwd)/migrations}"

if [ -n "${MYWEBAPP_DB_HOST:-}" ]; then
    export PGHOST="$MYWEBAPP_DB_HOST"
    export PGPORT="${MYWEBAPP_DB_PORT:-5432}"
    export PGDATABASE="${MYWEBAPP_DB_NAME:-mywebapp}"
    export PGUSER="${MYWEBAPP_DB_USER:-mywebapp}"
    export PGPASSWORD="${MYWEBAPP_DB_PASSWORD:?MYWEBAPP_DB_PASSWORD must be set}"
else
    CONFIG="${MYWEBAPP_CONFIG:-/etc/mywebapp/config.toml}"
    if [[ ! -r "$CONFIG" ]]; then
        echo "migrate.sh: cannot read config at $CONFIG" >&2
        exit 1
    fi
    read_db() {
        python3 - "$CONFIG" "$1" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    cfg = tomllib.load(f)
print(cfg["db"][sys.argv[2]])
PY
    }
    PGHOST=$(read_db host)
    PGPORT=$(read_db port)
    PGDATABASE=$(read_db name)
    PGUSER=$(read_db user)
    PGPASSWORD=$(read_db password)
    export PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD
fi

psql --quiet --no-psqlrc --set=ON_ERROR_STOP=1 \
    --file="$MIGRATIONS_DIR/schema_version.sql"

current_version=$(psql --quiet --no-psqlrc --tuples-only --no-align \
    --command='SELECT COALESCE(MAX(version), 0) FROM schema_version;')

shopt -s nullglob
applied=0
for sql in "$MIGRATIONS_DIR"/[0-9][0-9][0-9]_*.sql; do
    fname=$(basename "$sql")
    version=$((10#${fname%%_*}))
    if (( version <= current_version )); then
        continue
    fi
    echo "migrate.sh: applying ${fname} (version ${version})"
    psql --quiet --no-psqlrc --set=ON_ERROR_STOP=1 --single-transaction \
        --command="BEGIN;" \
        --file="$sql" \
        --command="INSERT INTO schema_version (version) VALUES (${version});" \
        --command="COMMIT;"
    applied=$((applied + 1))
done

if (( applied == 0 )); then
    echo "migrate.sh: schema already at version ${current_version}, nothing to do"
else
    echo "migrate.sh: applied ${applied} migration(s)"
fi
