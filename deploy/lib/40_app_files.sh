# shellcheck shell=bash
# Install application code under /opt/mywebapp; create venv; install runtime deps.
set -euo pipefail

APP_HOME=/opt/mywebapp

install -d -m 0755 -o mywebapp -g mywebapp "$APP_HOME"
install -d -m 0755 -o mywebapp -g mywebapp "$APP_HOME/app"
install -d -m 0755 -o mywebapp -g mywebapp "$APP_HOME/app/routes"
install -d -m 0755 -o mywebapp -g mywebapp "$APP_HOME/app/templates"
install -d -m 0755 -o mywebapp -g mywebapp "$APP_HOME/migrations"
install -d -m 0755 -o mywebapp -g mywebapp "$APP_HOME/scripts"
install -d -m 0755 -o root      -g root      /var/log/mywebapp

# Copy sources (idempotent — rsync would be nicer but avoid extra dep).
cp -a "$REPO_ROOT/app/."        "$APP_HOME/app/"
cp -a "$REPO_ROOT/migrations/." "$APP_HOME/migrations/"
cp -a "$REPO_ROOT/requirements.txt" "$APP_HOME/requirements.txt"

# Install bash scripts with strict perms.
install -m 0750 -o root -g mywebapp "$REPO_ROOT/scripts/migrate.sh"     "$APP_HOME/scripts/migrate.sh"
install -m 0750 -o root -g mywebapp "$REPO_ROOT/scripts/wait_for_pg.sh" "$APP_HOME/scripts/wait_for_pg.sh"

chown -R mywebapp:mywebapp "$APP_HOME/app" "$APP_HOME/migrations"

# Build / refresh the venv.
if [[ ! -x "$APP_HOME/.venv/bin/uvicorn" ]]; then
    python3.12 -m venv "$APP_HOME/.venv"
fi
"$APP_HOME/.venv/bin/pip" install --quiet --upgrade pip
"$APP_HOME/.venv/bin/pip" install --quiet --no-cache-dir -r "$APP_HOME/requirements.txt"
chown -R mywebapp:mywebapp "$APP_HOME/.venv"
