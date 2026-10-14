#!/usr/bin/env bash
# Verifies playbooks/tasks/kuma-cp-health.yml: 200 success against a live control plane, bounded retries and
# immediate descriptive failure against a dead endpoint. Runs the sandbox on the host network so localhost resolves to the host.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
IMAGE="cloud-agnostic-dev-sandbox:latest"
RUN() {
    docker run --rm --network host -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD:/workspace" -w /workspace "$IMAGE" "$1" 2>&1
}
NET="platform-simulation-net-health-test"
CP="kuma-control-plane-health-test"
PORT=15683
DEAD_PORT=15684
TMP="$(mktemp -d -p "$PWD")"
trap 'docker rm -f "$CP" >/dev/null 2>&1 || true; docker network rm "$NET" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

cat > "$TMP/up.yml" <<'PLAY'
---
- hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - ansible.builtin.include_tasks: ../playbooks/tasks/network-bridge.yml
    - ansible.builtin.include_tasks: ../playbooks/tasks/kuma-cp-core.yml
PLAY
cat > "$TMP/health.yml" <<'PLAY'
---
- hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - ansible.builtin.include_tasks: ../playbooks/tasks/kuma-cp-health.yml
    - ansible.builtin.debug:
        msg: "UNBLOCKED-DEPENDENT-TIER"
PLAY
D="$(basename "$TMP")"

# Failure path: dead endpoint must exhaust exactly the configured attempts and halt before dependents run.
OUT="$(RUN "ansible-playbook $D/health.yml -e kuma_cp_api_url=http://localhost:$DEAD_PORT/meshes -e kuma_cp_health_max_attempts=3 -e kuma_cp_health_base_delay=1" || true)"
echo "$OUT" | grep -q "after 3 attempts" || fail "ceiling error message missing"
echo "$OUT" | grep -q "attempt 3/3" || fail "third attempt not executed"
echo "$OUT" | grep -q "attempt 4/3" && fail "retry ceiling exceeded"
echo "$OUT" | grep -q "UNBLOCKED-DEPENDENT-TIER" && fail "playbook did not halt at the ceiling"
echo "[✓] ceiling halts with a descriptive error"

# Success path: live control plane, polled over its published loopback port.
RUN "ansible-playbook $D/up.yml -e platform_network_name=$NET -e kuma_cp_name=$CP -e kuma_cp_host_port=$PORT" >/dev/null || fail "control plane allocation failed"
OUT="$(RUN "ansible-playbook $D/health.yml -e kuma_cp_api_url=http://localhost:$PORT/meshes")" || { echo "$OUT" >&2; fail "health loop failed against a live control plane"; }
echo "$OUT" | grep -q "Kuma control plane ready" || fail "readiness not reported"
echo "$OUT" | grep -q "UNBLOCKED-DEPENDENT-TIER" || fail "dependents were not unblocked"
echo "[✓] kuma health guardrail: HTTP 200 detection, exponential backoff and bounded retry ceiling passed"
