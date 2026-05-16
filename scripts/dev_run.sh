#!/usr/bin/env bash
# Local development runner — uses TCP bind, NOT systemd socket activation.
# The systemd path uses `uvicorn --fd 3` with an inherited socket; that mode
# only works under systemd because outside it FD 0 is stdin (footgun).
# For dev we use the simple --host/--port pair so --reload works and the
# usual tools (debugger, lsof) behave normally.

set -euo pipefail

cd "$(dirname "$0")/.."

export MYWEBAPP_CONFIG="${MYWEBAPP_CONFIG:-$PWD/deploy/config/config.dev.toml}"

if [[ ! -f "$MYWEBAPP_CONFIG" ]]; then
    echo "dev_run.sh: MYWEBAPP_CONFIG=$MYWEBAPP_CONFIG does not exist" >&2
    echo "Create it from deploy/config/config.toml.example or see docs/dev-setup.md" >&2
    exit 1
fi

exec .venv/bin/uvicorn --factory app.main:create_app --host 127.0.0.1 --port 8080 --reload
