#!/usr/bin/env bash
# End-to-end smoke checks.
#   --dev   → hit the app directly on 127.0.0.1:8080 (developer loop)
#   --prod  → hit nginx on 127.0.0.1:80 (post-install verification)
# Covers V1-01, V1-02, V1-05, V1-06, V1-08..V1-11, V1-14, V1-21, V1-26..V1-29.

set -euo pipefail

mode="${1:-}"
case "$mode" in
    --dev)  base="http://127.0.0.1:8080"; expect_health_external=200 ;;
    --prod) base="http://127.0.0.1:80";   expect_health_external=404 ;;
    *)
        echo "usage: $0 --dev|--prod" >&2
        exit 2
        ;;
esac

pass=0
fail=0
check() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS  $label  ($actual)"
        pass=$((pass + 1))
    else
        echo "FAIL  $label  expected=$expected actual=$actual"
        fail=$((fail + 1))
    fi
}

curl_code() {
    curl -sS -o /dev/null -w '%{http_code}' "$@"
}

curl_ct() {
    curl -sSI "$@" | awk 'tolower($1)=="content-type:"{print tolower($2)}' | tr -d '\r;'
}

# Liveness
check "alive direct"   200 "$(curl_code "$base/health/alive" || true)"
check "ready direct"   200 "$(curl_code "$base/health/ready" || true)"

# Items list (JSON)
check "items json 200" 200 "$(curl_code -H 'Accept: application/json' "$base/items" || true)"

# Items list (HTML)
ct_html=$(curl_ct -H 'Accept: text/html' "$base/items" || true)
check "items html content-type" "text/html" "$ct_html"

# Create item via POST
new_id=$(curl -sS -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -d '{"name":"smoke-bolt","quantity":42}' "$base/items" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
check "post created id present" "true" "$([[ -n $new_id ]] && echo true || echo false)"

# Get item by id
check "get by id 200" 200 "$(curl_code -H 'Accept: application/json' "$base/items/$new_id" || true)"

# Invalid JSON → 422
check "invalid json 422" 422 "$(curl_code -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' --data '{not json' "$base/items" || true)"

# Root endpoint HTML
ct_root=$(curl_ct -H 'Accept: text/html' "$base/" || true)
check "root html content-type" "text/html" "$ct_root"

# Negotiation matrix
check "items accept json type" "application/json" "$(curl_ct -H 'Accept: application/json' "$base/items" || true)"
check "items accept html type" "text/html"        "$(curl_ct -H 'Accept: text/html' "$base/items" || true)"
check "root accept html"       200                "$(curl_code -H 'Accept: text/html' "$base/" || true)"

# External health visibility
check "external /health/alive" "$expect_health_external" "$(curl_code "$base/health/alive" || true)"

# In --prod, nginx allow-list extras
if [[ "$mode" == "--prod" ]]; then
    check "external /admin 404"  404 "$(curl_code "$base/admin"  || true)"
    check "external /.env 404"   404 "$(curl_code "$base/.env"   || true)"
fi

echo
echo "summary: $pass passed, $fail failed"
exit "$fail"
