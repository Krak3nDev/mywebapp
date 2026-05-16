#!/usr/bin/env bash
# mywebapp — single-entry installer for a fresh Ubuntu 24.04 LTS VM.
# Idempotent: every mutating step guards on current state and converges.

set -euo pipefail

SKIP_LOCKOUT=0
for arg in "$@"; do
    case "$arg" in
        --skip-lockout) SKIP_LOCKOUT=1 ;;
        -h|--help)
            echo "usage: $0 [--skip-lockout]"
            exit 0
            ;;
        *)
            echo "unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "install.sh: must run as root" >&2
    exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
export HERE REPO_ROOT

# Mirror full log to /var/log/mywebapp-install.log while also showing live output.
LOG=/var/log/mywebapp-install.log
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "==== install.sh started $(date -Is) ===="

for step in "$HERE"/lib/[0-9][0-9]_*.sh; do
    echo "---- running $(basename "$step") ----"
    # shellcheck source=/dev/null
    source "$step"
done

if (( SKIP_LOCKOUT == 0 )); then
    echo "---- running lib/90_lockout.sh ----"
    # shellcheck source=/dev/null
    source "$HERE/lib/90_lockout.sh"
fi

echo "---- running lib/99_verify.sh ----"
# shellcheck source=/dev/null
source "$HERE/lib/99_verify.sh"

echo "==== install.sh finished $(date -Is) ===="
echo "Try: curl http://127.0.0.1/items"
