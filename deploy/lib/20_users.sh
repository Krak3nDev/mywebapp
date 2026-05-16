# shellcheck shell=bash
# Create system + admin users with the required privileges and password policy.
set -euo pipefail

create_admin() {
    local name="$1"
    if ! id -u "$name" >/dev/null 2>&1; then
        useradd --create-home --shell /bin/bash "$name"
    fi
    usermod -aG sudo "$name"
}

# student: admin account for the student. Password is intentionally not set
# here — the user creates one manually (or the cloud image provided it).
create_admin student

# teacher: admin account, default password 12345678, force-change-on-first-login.
create_admin teacher
echo 'teacher:12345678' | chpasswd
if chage -l teacher | grep -qiE 'password expires.*never'; then
    chage -d 0 teacher
elif ! chage -l teacher | grep -qi 'password must be changed'; then
    chage -d 0 teacher
fi

# mywebapp: system user, no shell, no home — runs the service.
if ! id -u mywebapp >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin --user-group mywebapp
fi

# operator: restricted account, default password 12345678, force-change.
if ! id -u operator >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash operator
fi
echo 'operator:12345678' | chpasswd
if ! chage -l operator | grep -qi 'password must be changed'; then
    chage -d 0 operator
fi

# Ensure operator is NOT in sudo group (its sudo rights come from sudoers.d).
if id -nG operator | tr ' ' '\n' | grep -qx sudo; then
    deluser operator sudo
fi
