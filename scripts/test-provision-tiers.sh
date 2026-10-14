#!/usr/bin/env bash
# Verifies playbooks/tasks/provision-tiers.yml: blueprint-driven tiers, network membership, running state, caps, idempotency.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
RUN() { bash scripts/sandbox-run.sh "$1" 2>&1; }
NET="platform-simulation-net-tiers-test"
PFX="tiertest-"
TMP="$(mktemp -d -p "$PWD")"
NAMES=(eccs-compute-nodes calbs-cagis-ingress mkrs-k8s-workload)
cleanup() {
    for n in "${NAMES[@]}"; do docker rm -f "${PFX}${n}" >/dev/null 2>&1 || true; done
    docker network rm "$NET" >/dev/null 2>&1 || true
    rm -rf "$TMP"
}
trap cleanup EXIT

cat > "$TMP/play.yml" <<'PLAY'
---
- hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - ansible.builtin.include_tasks: ../playbooks/tasks/network-bridge.yml
    - ansible.builtin.include_tasks: ../playbooks/tasks/provision-tiers.yml
PLAY

CMD="ansible-playbook $(basename "$TMP")/play.yml -e platform_network_name=$NET -e tier_name_prefix=$PFX"
RUN "$CMD" >/dev/null || fail "first run failed"

check() { # name cpus mem_mb
    local c="${PFX}$1"
    [ "$(docker inspect "$c" --format '{{.State.Status}}')" = "running" ] || fail "$1 not running"
    [ "$(docker inspect "$c" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')" = "$NET " ] || fail "$1 not confined to $NET"
    [ "$(docker inspect "$c" --format '{{.HostConfig.NanoCpus}}')" = "$(($2 * 1000000000))" ] || fail "$1 cpu cap mismatch"
    [ "$(docker inspect "$c" --format '{{.HostConfig.Memory}}')" = "$(($3 * 1048576))" ] || fail "$1 memory cap mismatch"
}
check eccs-compute-nodes 5 10240
check calbs-cagis-ingress 1 2048
check mkrs-k8s-workload 1 2048
[ "$(docker inspect "${PFX}calbs-cagis-ingress" --format '{{index .Config.Labels "kuma.io/gateway"}}')" = "enabled" ] || fail "blueprint tags not propagated as labels"

RUN "$CMD" | grep -q "changed=0" || fail "second run not idempotent"
echo "[✓] tier provisioning: 3 blueprint tiers running on the isolated network with caps, labels and idempotency passed"
