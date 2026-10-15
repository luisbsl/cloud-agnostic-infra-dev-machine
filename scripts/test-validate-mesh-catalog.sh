#!/usr/bin/env bash
# Verifies playbooks/tasks/validate-mesh-catalog.yml against a mock Kuma REST API: a catalog matching the blueprint
# passes; a missing Dataplane, a drifted kuma.io/service token and an unreachable API each fail with a descriptive error.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
IMAGE="cloud-agnostic-dev-sandbox:latest"
RUN() {
    docker run --rm --network host -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/workspace" -w /workspace "$IMAGE" "$1" 2>&1
}
PORT=15685
DEAD_PORT=15686
TMP="$(mktemp -d -p "$PWD")"
D="$(basename "$TMP")"
MOCK_PID=""
trap '[ -z "$MOCK_PID" ] || kill "$MOCK_PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT

# Serves $TMP/catalog.json at the Kuma dataplane catalog path.
cat > "$TMP/mock.py" <<'PY'
import http.server, sys
root, port = sys.argv[1], int(sys.argv[2])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/meshes/platform-simulation-vpc/dataplanes":
            self.send_response(404); self.end_headers(); return
        body = open(root + "/catalog.json", "rb").read()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", port), H).serve_forever()
PY
python3 "$TMP/mock.py" "$TMP" "$PORT" & MOCK_PID=$!

cat > "$TMP/catalog.yml" <<'PLAY'
---
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    blueprint: "{{ lookup('ansible.builtin.file', playbook_dir ~ '/../blueprints/platform-services.json') | from_json }}"
    target_mesh: "{{ blueprint.mesh }}"
    expected_containers: "{{ blueprint.services }}"
    kuma_api_url: "http://localhost:15685"
    require_provisioned: true
  tasks:
    - ansible.builtin.include_tasks: ../playbooks/tasks/validate-mesh-catalog.yml
    - ansible.builtin.debug:
        msg: "CATALOG-VALIDATED"
PLAY

catalog() { # <eccs-token> <include-mkrs: yes|no>
    local mkrs=',{"name":"mkrs-k8s-workload","mesh":"platform-simulation-vpc","networking":{"inbound":[{"tags":{"kuma.io/service":"mkrs-workload-svc"}}]}}'
    [ "$2" = yes ] || mkrs=""
    cat > "$TMP/catalog.json" <<JSON
{"total":3,"items":[
{"name":"eccs-compute-nodes","mesh":"platform-simulation-vpc","networking":{"inbound":[{"tags":{"kuma.io/service":"$1","tier":"tier-1-eccs"}}]}},
{"name":"calbs-cagis-ingress","mesh":"platform-simulation-vpc","networking":{"inbound":[{"tags":{"kuma.io/service":"ingress-gateway-svc","kuma.io/gateway":"enabled"}}]}}
$mkrs]}
JSON
}
sleep 1

catalog eccs-compute-svc yes
OUT="$(RUN "ansible-playbook $D/catalog.yml")" || { echo "$OUT" >&2; fail "valid catalog rejected"; }
for n in eccs-compute-nodes calbs-cagis-ingress mkrs-k8s-workload; do
    echo "$OUT" | grep -q "Verified Dataplane $n" || fail "$n not verified"
done
echo "$OUT" | grep -q "CATALOG-VALIDATED" || fail "playbook did not complete"
echo "[✓] catalog with all three blueprint tokens passes"

catalog eccs-compute-svc no
OUT="$(RUN "ansible-playbook $D/catalog.yml" || true)"
echo "$OUT" | grep -q "mkrs-k8s-workload is not registered" || fail "missing Dataplane not reported"
echo "$OUT" | grep -q "CATALOG-VALIDATED" && fail "missing Dataplane did not halt"
echo "[✓] missing Dataplane fails descriptively"

catalog wrong-svc yes
OUT="$(RUN "ansible-playbook $D/catalog.yml" || true)"
echo "$OUT" | grep -q "blueprint expects eccs-compute-svc" || fail "token drift not reported"
echo "$OUT" | grep -q "CATALOG-VALIDATED" && fail "token drift did not halt"
echo "[✓] kuma.io/service token drift fails descriptively"

OUT="$(RUN "ansible-playbook $D/catalog.yml -e kuma_api_url=http://localhost:$DEAD_PORT" || true)"
echo "$OUT" | grep -q "dataplanes is unreachable" || fail "unreachable API not reported"
echo "$OUT" | grep -q "CATALOG-VALIDATED" && fail "unreachable API did not halt"
echo "[✓] unreachable catalog fails descriptively"
echo "[✓] mesh catalog validation passed"
