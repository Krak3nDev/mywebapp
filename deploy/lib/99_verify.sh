# shellcheck shell=bash
# Post-install smoke from inside the VM.
set -euo pipefail

fail=0
check_code() {
    local label="$1" expected="$2" url="$3" headers=("${@:4}")
    local actual
    actual="$(curl -sS -o /dev/null -w '%{http_code}' "${headers[@]}" "$url" || true)"
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS  ${label} (${actual})"
    else
        echo "FAIL  ${label} expected=${expected} actual=${actual}"
        fail=$((fail + 1))
    fi
}

check_code 'health alive (loopback)' 200 'http://127.0.0.1:8080/health/alive'
check_code 'health ready (loopback)' 200 'http://127.0.0.1:8080/health/ready'
check_code 'root via nginx'          200 'http://127.0.0.1/'  -H 'Accept: text/html'
check_code 'items via nginx (json)'  200 'http://127.0.0.1/items' -H 'Accept: application/json'
check_code 'health blocked externally' 404 'http://127.0.0.1/health/alive'
check_code 'unknown path 404'         404 'http://127.0.0.1/admin'
check_code 'dotfile 404'              404 'http://127.0.0.1/.env'

if (( fail > 0 )); then
    echo "99_verify.sh: ${fail} check(s) failed" >&2
    exit 1
fi
echo "99_verify.sh: all post-install checks passed"
