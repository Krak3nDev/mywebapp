# shellcheck shell=bash
# Render /etc/mywebapp/config.toml with locked-down permissions.
set -euo pipefail

install -d -m 0750 -o root -g mywebapp /etc/mywebapp

cat > /etc/mywebapp/config.toml <<EOF
[server]
host = "127.0.0.1"
port = 8080

[db]
host = "127.0.0.1"
port = 5432
name = "mywebapp"
user = "mywebapp"
password = "${DB_PASSWORD}"
pool_min = 2
pool_max = 10

[log]
level = "INFO"
EOF

chown root:mywebapp /etc/mywebapp/config.toml
chmod 0640 /etc/mywebapp/config.toml
