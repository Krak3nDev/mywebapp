#!/usr/bin/env bash
# Лабораторна №3 — target node bootstrap.
# Provisions a fresh Ubuntu 24.04 VM as the deploy target:
#   - docker engine + compose plugin
#   - postgres + nginx are containerized via /opt/mywebapp/compose.prod.yml
#   - systemd unit mywebapp-container.service manages the stack lifecycle
#   - ufw allows 22/80, blocks 5432/8080 externally
# Re-run safe.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "target-node-install.sh: must run as root" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_HOME=/opt/mywebapp

export DEBIAN_FRONTEND=noninteractive

echo "==> apt update + base packages"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg lsb-release ufw

echo "==> install docker (official repo if not present)"
if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

echo "==> mywebapp system user"
if ! id -u mywebapp >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin --user-group mywebapp
fi
usermod -aG docker mywebapp || true

echo "==> ${APP_HOME} layout"
install -d -m 0750 -o root -g root "${APP_HOME}"
install -d -m 0755 -o root -g root "${APP_HOME}/scripts" "${APP_HOME}/deploy/nginx"
install -m 0644 "${REPO_ROOT}/deploy/compose.prod.yml"             "${APP_HOME}/compose.prod.yml"
install -m 0644 "${REPO_ROOT}/deploy/nginx/mywebapp.compose.conf"  "${APP_HOME}/deploy/nginx/mywebapp.compose.conf"
install -m 0750 "${REPO_ROOT}/scripts/migrate.sh"                  "${APP_HOME}/scripts/migrate.sh"

echo "==> /opt/mywebapp/.env (generate once; preserve secrets on re-run)"
ENV_FILE="${APP_HOME}/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo "    .env already present — leaving secrets intact"
else
    PG_PW="$(openssl rand -hex 24)"
    APP_PW="$PG_PW"
    cat > "$ENV_FILE" <<EOF
IMAGE=ghcr.io/krak3ndev/mywebapp:stable
MYWEBAPP_HOST_PORT=80
POSTGRES_USER=mywebapp
POSTGRES_PASSWORD=${PG_PW}
POSTGRES_DB=mywebapp
MYWEBAPP_DB_PASSWORD=${APP_PW}
EOF
    chmod 0640 "$ENV_FILE"
    chown root:root "$ENV_FILE"
fi

echo "==> systemd unit"
install -m 0644 "${REPO_ROOT}/deploy/systemd/mywebapp-container.service" \
    /etc/systemd/system/mywebapp-container.service
systemctl daemon-reload
systemctl enable mywebapp-container.service

echo "==> ufw firewall"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw --force enable

echo "==> done. Pull image and start with:"
echo "    sudo systemctl start mywebapp-container.service"
echo "    sudo systemctl status mywebapp-container.service"
