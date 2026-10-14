#!/usr/bin/env bash
# Verifies playbooks/tasks/network-bridge.yml: network creation, MTU option, and idempotency.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
RUN() { bash scripts/sandbox-run.sh "$1" 2>&1; }
NET="platform-simulation-net-test"
TMP="$(mktemp -d -p "$PWD")"
trap 'docker network rm "$NET" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

cat > "$TMP/play.yml" <<'EOF'
---
- hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - ansible.builtin.include_tasks: ../playbooks/tasks/network-bridge.yml
EOF

CMD="ansible-playbook $(basename "$TMP")/play.yml -e platform_network_name=$NET"
RUN "$CMD" | grep -q "changed=1" || fail "first run did not create the network"
[ "$(docker network inspect "$NET" --format '{{.Driver}}')" = "bridge" ] || fail "driver is not bridge"
[ "$(docker network inspect "$NET" --format '{{index .Options "com.docker.network.driver.mtu"}}')" = "1500" ] || fail "MTU option is not 1500"
label() { docker network inspect "$NET" --format "{{index .Labels \"$1\"}}"; }
[ "$(label platform.simulation.isolated)" = "true" ] || fail "isolated label missing"
STAMP="$(label platform.simulation.compiled.at)"
[ -n "$STAMP" ] || fail "compiled.at label missing"
sleep 2
RUN "$CMD" | grep -q "changed=0" || fail "second run not idempotent"
[ "$(label platform.simulation.compiled.at)" = "$STAMP" ] || fail "compiled.at label drifted"
echo "[✓] network creation, MTU 1500, insulation labels and idempotency passed"
