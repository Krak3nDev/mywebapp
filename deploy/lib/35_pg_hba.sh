# shellcheck shell=bash
# Tighten pg_hba.conf — TCP from 127.0.0.1 only with scram-sha-256.
set -euo pipefail

hba="$(sudo -u postgres psql -tAc 'SHOW hba_file;')"
desired_line='host    mywebapp        mywebapp        127.0.0.1/32            scram-sha-256'

if ! grep -qF "$desired_line" "$hba"; then
    # Strip any prior mywebapp-host line, then append the desired one.
    sed -i -E '/^host\s+mywebapp\s+mywebapp\s+127\.0\.0\.1\/32/d' "$hba"
    printf '%s\n' "$desired_line" >> "$hba"
    systemctl reload postgresql.service
fi
