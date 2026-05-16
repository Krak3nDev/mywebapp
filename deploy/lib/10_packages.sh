# shellcheck shell=bash
# Install OS packages.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    python3.12 python3.12-venv python3-pip \
    postgresql postgresql-client \
    nginx \
    sudo \
    ca-certificates curl jq \
    openssh-server

systemctl enable --now postgresql.service nginx.service ssh.service
