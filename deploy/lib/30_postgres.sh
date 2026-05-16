# shellcheck shell=bash
# Configure PostgreSQL to listen only on 127.0.0.1; create role + database.
set -euo pipefail

# 1) listen_addresses: diff-then-restart only if changed.
pg_conf="$(sudo -u postgres psql -tAc 'SHOW config_file;')"
desired_listen="'127.0.0.1'"
current_listen="$(grep -E '^\s*listen_addresses\s*=' "$pg_conf" || true)"
if [[ "$current_listen" != *"listen_addresses = $desired_listen"* ]]; then
    sed -i -E "s|^#?\s*listen_addresses\s*=.*|listen_addresses = $desired_listen|" "$pg_conf"
    PG_NEEDS_RESTART=1
else
    PG_NEEDS_RESTART=0
fi

# 2) Role + database.
PG_PASS_FILE=/etc/mywebapp/.pgpass
if [[ -f "$PG_PASS_FILE" ]]; then
    DB_PASSWORD="$(cat "$PG_PASS_FILE")"
else
    DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=')"
    install -d -m 0750 -o root -g root /etc/mywebapp
    umask 077
    printf '%s' "$DB_PASSWORD" > "$PG_PASS_FILE"
fi
export DB_PASSWORD

sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mywebapp') THEN
        CREATE ROLE mywebapp LOGIN PASSWORD '${DB_PASSWORD}';
    ELSE
        ALTER ROLE mywebapp WITH LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
END
\$\$;
SQL

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='mywebapp';" | grep -q 1; then
    sudo -u postgres createdb -O mywebapp mywebapp
fi

if (( PG_NEEDS_RESTART == 1 )); then
    systemctl restart postgresql.service
fi
