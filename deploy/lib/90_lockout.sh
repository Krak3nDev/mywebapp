# shellcheck shell=bash
# Final hardening: gradebook file, sshd assertions, default-user lockout.
# Runs AFTER all other steps so we can verify operator reachability first.
set -euo pipefail

# 1) Gradebook (lab requirement 10).
echo "5" > /home/student/gradebook
chown student:student /home/student/gradebook
chmod 0644 /home/student/gradebook

# 2) sshd config must let operator log in interactively so chage's
#    forced password change actually fires on first SSH attempt.
sshd_cfg="$(sshd -T 2>/dev/null || true)"
require_yes() {
    local key="$1"
    if ! grep -qE "^${key} yes" <<<"$sshd_cfg"; then
        echo "90_lockout.sh: sshd ${key} is not 'yes'; aborting before lockout" >&2
        exit 1
    fi
}
require_yes passwordauthentication
require_yes kbdinteractiveauthentication

# operator must exist
getent passwd operator >/dev/null

# Honour AllowUsers / DenyUsers if present.
if grep -q '^denyusers ' <<<"$sshd_cfg"; then
    if grep -qE '^denyusers .*\boperator\b' <<<"$sshd_cfg"; then
        echo "90_lockout.sh: operator is in sshd DenyUsers; aborting" >&2
        exit 1
    fi
fi
if grep -q '^allowusers ' <<<"$sshd_cfg"; then
    if ! grep -qE '^allowusers .*\boperator\b' <<<"$sshd_cfg"; then
        echo "90_lockout.sh: AllowUsers set but operator missing; aborting" >&2
        exit 1
    fi
fi

# 3) Lock the default cloud user. Refuse to lock the user who started us.
default_user="${DEFAULT_USER:-ubuntu}"
if [[ "$default_user" == "${CURRENT_USER:-}" ]]; then
    echo "90_lockout.sh: refusing to lock currently-logged-in user ${default_user}" >&2
    exit 1
fi
if id "$default_user" >/dev/null 2>&1 && [[ "$default_user" != "student" && "$default_user" != "teacher" && "$default_user" != "operator" ]]; then
    usermod -L "$default_user"
    usermod -e 1 "$default_user"
    chsh -s /usr/sbin/nologin "$default_user" || true
    echo "90_lockout.sh: locked default user ${default_user}"
else
    echo "90_lockout.sh: default user ${default_user} absent or is one of {student,teacher,operator}; skipping"
fi
