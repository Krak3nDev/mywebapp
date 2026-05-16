#!/usr/bin/env bash
# Idempotent, version-aware migration runner.
# Reads PG connection details from $MYWEBAPP_CONFIG (default /etc/mywebapp/config.toml),
# applies migrations/*.sql in numeric order, records version in schema_version.
# Each migration runs inside a single transaction — partial commits never happen.

set -euo pipefail

CONFIG="${MYWEBAPP_CONFIG:-/etc/mywebapp/config.toml}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-$(cd "$(dirname "$0")/.." && pwd)/migrations}"

if [[ ! -r "$CONFIG" ]]; then
    echo "migrate.sh: cannot read config at $CONFIG" >&2
    exit 1
fi

# Extract [db] section values using a Python one-liner (stdlib tomllib).
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

# Bootstrap schema_version table.
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
