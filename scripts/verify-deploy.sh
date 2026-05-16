#!/usr/bin/env bash
# Лабораторна №3 — post-deploy verification.
# Runs ON the self-hosted runner; talks to TARGET via HTTP only.
# Pass-fail script: exits non-zero if any check fails.

set -euo pipefail

TARGET="${TARGET:?TARGET must be set (host or IP of target node)}"
TARGET_HTTP_PORT="${TARGET_HTTP_PORT:-80}"
if [[ "$TARGET_HTTP_PORT" == "80" ]]; then
    BASE="http://${TARGET}"
else
    BASE="http://${TARGET}:${TARGET_HTTP_PORT}"
fi

pass=0
fail=0

check_code() {
    local label="$1" expected="$2" url="$3"
    shift 3
    local actual
    actual="$(curl -sS -o /dev/null --max-time 10 -w '%{http_code}' "$@" "$url" || echo "000")"
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS  ${label}  (${actual})"
        pass=$((pass + 1))
    else
        echo "FAIL  ${label}  expected=${expected} actual=${actual}"
        fail=$((fail + 1))
    fi
}

check_json_items() {
    local body
    body="$(curl -sS --max-time 10 -H 'Accept: application/json' "${BASE}/items" || echo "")"
    if echo "$body" | python3 -c 'import json, sys; sys.exit(0 if isinstance(json.load(sys.stdin), list) else 1)' 2>/dev/null; then
        echo "PASS  items JSON valid array"
        pass=$((pass + 1))
    else
        echo "FAIL  items JSON invalid (body: ${body:0:120})"
        fail=$((fail + 1))
    fi
}

echo "== verify-deploy.sh against ${BASE} =="

check_code "items 200"      200 "${BASE}/items" -H 'Accept: application/json'
check_json_items
check_code "items HTML 200" 200 "${BASE}/items" -H 'Accept: text/html'
check_code "root HTML 200"  200 "${BASE}/"      -H 'Accept: text/html'
check_code "admin 404"      404 "${BASE}/admin"
check_code "dotfile 404"    404 "${BASE}/.env"
check_code "health blocked externally" 404 "${BASE}/health/alive"

# POST + GET roundtrip
NAME="verify-test-$(date +%s)"
created="$(curl -sS --max-time 10 -X POST \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "{\"name\":\"${NAME}\",\"quantity\":1}" \
    "${BASE}/items" || echo '')"
new_id="$(echo "$created" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' 2>/dev/null || echo '')"
if [[ -n "$new_id" ]]; then
    echo "PASS  POST created id=${new_id}"
    pass=$((pass + 1))
    check_code "GET created 200" 200 "${BASE}/items/${new_id}" -H 'Accept: application/json'
else
    echo "FAIL  POST returned no id (body: ${created:0:120})"
    fail=$((fail + 1))
fi

echo
echo "summary: ${pass} passed, ${fail} failed"
exit "$fail"
