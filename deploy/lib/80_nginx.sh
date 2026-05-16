# shellcheck shell=bash
# Configure nginx as reverse proxy. Default site is replaced by mywebapp's allow-list.
set -euo pipefail

# Back up any existing default site before clobbering.
if [[ -f /etc/nginx/sites-enabled/default && ! -L /etc/nginx/sites-enabled/default ]]; then
    cp /etc/nginx/sites-enabled/default "/etc/nginx/sites-enabled/default.$(date +%Y%m%d-%H%M%S).bak"
fi
rm -f /etc/nginx/sites-enabled/default

install -m 0644 -o root -g root "$REPO_ROOT/deploy/nginx/mywebapp.conf" /etc/nginx/sites-available/mywebapp.conf
ln -sf /etc/nginx/sites-available/mywebapp.conf /etc/nginx/sites-enabled/mywebapp.conf

nginx -t
systemctl reload nginx.service
