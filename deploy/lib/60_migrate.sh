# shellcheck shell=bash
# Run database migrations as the mywebapp user.
set -euo pipefail

sudo -u mywebapp \
    MYWEBAPP_CONFIG=/etc/mywebapp/config.toml \
    MIGRATIONS_DIR=/opt/mywebapp/migrations \
    /opt/mywebapp/scripts/migrate.sh
