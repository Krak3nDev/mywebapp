# shellcheck shell=bash
# Install /etc/sudoers.d/operator-mywebapp atomically with visudo validation.
set -euo pipefail

src="$REPO_ROOT/deploy/sudoers/operator-mywebapp"
dst=/etc/sudoers.d/operator-mywebapp
tmp="$(mktemp /tmp/operator-mywebapp.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

install -m 0440 -o root -g root "$src" "$tmp"

if ! visudo -cf "$tmp"; then
    echo "85_sudoers.sh: visudo rejected the sudoers fragment — aborting" >&2
    exit 1
fi

install -m 0440 -o root -g root "$tmp" "$dst"
