#!/usr/bin/env bash
# Verifies playbooks/tasks/validate-path-isolation.yml against a mock Kuma REST API and two real containers:
# an enforced-mTLS mesh with a closed workload port passes; open plaintext path, disabled mTLS and allow-all
# TrafficPermission each fail with a descriptive error.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
IMAGE="cloud-agnostic-dev-sandbox:latest"
RUN() {
    docker run --rm --network host -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/workspace" -w /workspace "$IMAGE" "$1" 2>&1
}
NET="platform-simulation-net-iso-test"
SRC="iso-test-ingress"
DST="iso-test-workload"
PORT=15687
TMP="$(mktemp -d -p "$PWD")"
D="$(basename "$TMP")"
MOCK_PID=""
trap '[ -z "$MOCK_PID" ] || kill "$MOCK_PID" 2>/dev/null || true; docker rm -f "$SRC" "$DST" >/dev/null 2>&1 || true; docker network rm "$NET" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

mkdir -p "$TMP/api"
cat > "$TMP/mock.py" <<'PY'
import http.server, os, sys
root, port = sys.argv[1], int(sys.argv[2])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        f = root + "/api/" + self.path.rstrip("/").replace("/", "_") + ".json"
        if not os.path.exists(f):
            self.send_response(404); self.end_headers(); return
        body = open(f, "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", port), H).serve_forever()
PY
python3 "$TMP/mock.py" "$TMP" "$PORT" & MOCK_PID=$!

mesh() { # <mtls: on|off> <allow-all: yes|no>
    local m='{"name":"platform-simulation-vpc","mtls":{"enabledBackend":"ca-1","backends":[{"name":"ca-1","type":"builtin"}]}}'
    [ "$1" = on ] || m='{"name":"platform-simulation-vpc"}'
    echo "$m" > "$TMP/api/_meshes_platform-simulation-vpc.json"
    local p='{"items":[{"name":"scoped","sources":[{"match":{"kuma.io/service":"ingress-gateway-svc"}}],"destinations":[{"match":{"kuma.io/service":"mkrs-workload-svc"}}]}]}'
    [ "$2" = no ] || p='{"items":[{"name":"allow-all-traffic","sources":[{"match":{"kuma.io/service":"*"}}],"destinations":[{"match":{"kuma.io/service":"*"}}]}]}'
    echo "$p" > "$TMP/api/_meshes_platform-simulation-vpc_traffic-permissions.json"
}

cat > "$TMP/iso.yml" <<'PLAY'
---
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    target_mesh: platform-simulation-vpc
    kuma_api_url: "http://localhost:15687"
    require_provisioned: true
    platform_network_name: platform-simulation-net-iso-test
    isolation_source: iso-test-ingress
    isolation_target: iso-test-workload
    isolation_target_port: 15688
    isolation_probe_timeout: 2
  tasks:
    - ansible.builtin.include_tasks: ../playbooks/tasks/validate-path-isolation.yml
    - ansible.builtin.debug:
        msg: "ISOLATION-VALIDATED"
PLAY

docker network create "$NET" >/dev/null
for c in "$SRC" "$DST"; do docker run -d --name "$c" --network "$NET" docker.io/library/alpine:3.24.2 sleep infinity >/dev/null; done
sleep 1

mesh on no
OUT="$(RUN "ansible-playbook $D/iso.yml")" || { echo "$OUT" >&2; fail "isolated mesh rejected"; }
echo "$OUT" | grep -q "ISOLATION-VALIDATED" || fail "playbook did not complete"
echo "$OUT" | grep -q "rejected (non-mTLS path blocked)" || fail "rejection not reported"
echo "[✓] enforced mTLS and blocked plaintext path pass"

# Control: an open plaintext listener proves the probe really detects an unauthenticated path.
docker exec -d "$DST" nc -lk -p 15688 -e /bin/true
sleep 1
OUT="$(RUN "ansible-playbook $D/iso.yml" || true)"
echo "$OUT" | grep -q "was not rejected" || fail "open plaintext path not detected"
echo "$OUT" | grep -q "ISOLATION-VALIDATED" && fail "open plaintext path did not halt"
echo "[✓] reachable plaintext path fails descriptively"
docker rm -f "$DST" >/dev/null; docker run -d --name "$DST" --network "$NET" docker.io/library/alpine:3.24.2 sleep infinity >/dev/null

mesh off no
OUT="$(RUN "ansible-playbook $D/iso.yml" || true)"
echo "$OUT" | grep -q "mTLS disabled" || fail "disabled mTLS not reported"
echo "$OUT" | grep -q "ISOLATION-VALIDATED" && fail "disabled mTLS did not halt"
echo "[✓] disabled mTLS fails descriptively"

mesh on yes
OUT="$(RUN "ansible-playbook $D/iso.yml" || true)"
echo "$OUT" | grep -q "allow-all TrafficPermission present: allow-all-traffic" || fail "allow-all permission not reported"
echo "$OUT" | grep -q "ISOLATION-VALIDATED" && fail "allow-all permission did not halt"
echo "[✓] allow-all TrafficPermission fails descriptively"
echo "[✓] zero-trust path isolation validation passed"
