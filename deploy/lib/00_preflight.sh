# shellcheck shell=bash
# Preflight: refuse to run on anything we haven't tested.
set -euo pipefail

if ! command -v lsb_release >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq lsb-release
fi

distro="$(lsb_release -is 2>/dev/null || echo unknown)"
release="$(lsb_release -rs 2>/dev/null || echo unknown)"
echo "preflight: detected ${distro} ${release}"
if [[ "$distro" != "Ubuntu" ]]; then
    echo "preflight: this installer targets Ubuntu (got ${distro}); aborting" >&2
    exit 1
fi

# Refuse to lock the user who is currently running the installer.
current_user="$(logname 2>/dev/null || echo "${SUDO_USER:-root}")"
export CURRENT_USER="$current_user"
echo "preflight: installer invoked by ${current_user}"

if ! ping -c1 -W2 archive.ubuntu.com >/dev/null 2>&1; then
    echo "preflight: cannot reach archive.ubuntu.com — check network" >&2
    exit 1
fi
