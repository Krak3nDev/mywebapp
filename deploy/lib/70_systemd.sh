# shellcheck shell=bash
# Install systemd units and enable socket activation.
set -euo pipefail

install -m 0644 -o root -g root "$REPO_ROOT/deploy/systemd/mywebapp.socket"  /etc/systemd/system/mywebapp.socket
install -m 0644 -o root -g root "$REPO_ROOT/deploy/systemd/mywebapp.service" /etc/systemd/system/mywebapp.service

systemctl daemon-reload

# Make sure the socket is enabled first — service is triggered through it.
systemctl enable --now mywebapp.socket
systemctl restart mywebapp.service
