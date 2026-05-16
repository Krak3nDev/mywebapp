#!/usr/bin/env bash
# Bounded wait for PostgreSQL to accept connections.
# Used as ExecStartPre= before migrate.sh so a slow cold-boot PG does not
# burn through StartLimitBurst. Hard cap = 60s.

set -euo pipefail

PG_SOCKET_DIR="${PG_SOCKET_DIR:-/var/run/postgresql}"
PG_PROBE_USER="${PG_PROBE_USER:-postgres}"

deadline=$(( $(date +%s) + 60 ))
while (( $(date +%s) < deadline )); do
    if pg_isready -h "$PG_SOCKET_DIR" -U "$PG_PROBE_USER" -t 2 >/dev/null 2>&1; then
        exit 0
    fi
    sleep 1
done

echo "wait_for_pg.sh: timed out after 60s waiting for PostgreSQL" >&2
exit 1
