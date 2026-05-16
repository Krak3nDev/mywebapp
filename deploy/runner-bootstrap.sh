#!/usr/bin/env bash
# Лабораторна №3 — self-hosted runner bootstrap.
# Provisions a SEPARATE Ubuntu 24.04 VM as a GitHub Actions self-hosted runner.
# Does NOT register the runner (token-based registration is manual, per spec).

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "runner-bootstrap.sh: must run as root" >&2
    exit 1
fi

RUNNER_HOME=/opt/actions-runner
RUNNER_USER=runner
RUNNER_VERSION="${RUNNER_VERSION:-2.319.1}"

# Auto-detect runner arch (x64 for amd64, arm64 for aarch64).
detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo x64 ;;
        aarch64|arm64) echo arm64 ;;
        *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
    esac
}
RUNNER_ARCH="${RUNNER_ARCH:-$(detect_arch)}"

export DEBIAN_FRONTEND=noninteractive

echo "==> apt update + prerequisites"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg lsb-release jq git openssh-client

echo "==> install docker (build cache + image push convenience)"
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

echo "==> runner user"
if ! id -u "$RUNNER_USER" >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "$RUNNER_HOME" --shell /bin/bash "$RUNNER_USER"
fi
usermod -aG docker "$RUNNER_USER" || true

echo "==> download actions-runner v${RUNNER_VERSION}"
ARCHIVE="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
if [[ ! -f "${RUNNER_HOME}/config.sh" ]]; then
    curl -fsSL -o "/tmp/${ARCHIVE}" \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${ARCHIVE}"
    sudo -u "$RUNNER_USER" tar -xzf "/tmp/${ARCHIVE}" -C "$RUNNER_HOME"
    rm -f "/tmp/${ARCHIVE}"
fi

cat <<'EOF'

================================================================
Runner downloaded but NOT registered (spec requires manual step).

Manual registration steps:

  1. Open: https://github.com/Krak3nDev/mywebapp/settings/actions/runners/new
     pick: Linux x64. Copy the --token value GitHub shows.

  2. Run on this VM:

       cd /opt/actions-runner
       sudo -u runner ./config.sh \
           --url https://github.com/Krak3nDev/mywebapp \
           --token <PASTE_TOKEN_HERE> \
           --labels lab3-runner \
           --unattended

  3. Install runner as a service:

       sudo ./svc.sh install runner
       sudo ./svc.sh start

After the lab is graded — stop / delete this VM (spec).
================================================================
EOF
