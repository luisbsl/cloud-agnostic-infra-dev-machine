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

# Blueprint contract (unclamped): the declared per-tier caps and the aggregate ceiling.
bp() { jq -r --arg n "$1" '.services[] | select(.name == $n) | "\(.resources.cpu) \(.resources.ramGb * 1024)"' blueprints/platform-services.json; }
[ "$(bp eccs-compute-nodes)" = "5 10240" ] || fail "eccs-compute-nodes blueprint caps are not 5 CPU / 10240 MB"
[ "$(bp calbs-cagis-ingress)" = "1 2048" ] || fail "calbs-cagis-ingress blueprint caps are not 1 CPU / 2048 MB"
[ "$(bp mkrs-k8s-workload)" = "1 2048" ] || fail "mkrs-k8s-workload blueprint caps are not 1 CPU / 2048 MB"
jq -e '([.services[].resources.cpu] | add) + 1 <= 8 and ([.services[].resources.ramGb] | add) * 1024 + 2048 <= 16384' \
    blueprints/platform-services.json >/dev/null || fail "blueprint plus Kuma exceeds the 8 vCPU / 16 GB ceiling"
echo "[✓] blueprint caps and aggregate ceiling verified"

# Oversized CPU cap must halt before any container is created, with a descriptive error.
jq --argjson n "$(docker info --format '{{.NCPU}}')" '.services[0].resources.cpu = ($n + 1)' blueprints/platform-services.json > "$TMP/oversized.json"
OUT="$(RUN "ansible-playbook $(basename "$TMP")/play.yml -e platform_network_name=$NET -e tier_name_prefix=$PFX -e tier_blueprint_path=/workspace/$(basename "$TMP")/oversized.json" || true)"
echo "$OUT" | grep -q "Docker daemon exposes only" || { echo "$OUT" >&2; fail "oversized CPU cap not rejected descriptively"; }
[ -z "$(docker ps -aq --filter name="^/${PFX}")" ] || fail "containers created despite oversized cap"
echo "[✓] oversized CPU cap halts with a descriptive error"

# Clamp blueprint CPU caps to the daemon's CPU count so the test also runs on small CI runners
# (Docker rejects caps above its CPU count). Real-blueprint sizing is enforced by validate-blueprint.sh.
NCPU="$(docker info --format '{{.NCPU}}')"
jq --argjson n "$NCPU" '.services |= map(.resources.cpu |= (if . > $n then $n else . end))' \
    blueprints/platform-services.json > "$TMP/blueprint.json"
exp_cpu() { jq -r --arg n "$1" '.services[] | select(.name == $n) | .resources.cpu' "$TMP/blueprint.json"; }
exp_mem() { jq -r --arg n "$1" '.services[] | select(.name == $n) | .resources.ramGb * 1024' "$TMP/blueprint.json"; }

CMD="ansible-playbook $(basename "$TMP")/play.yml -e platform_network_name=$NET -e tier_name_prefix=$PFX -e tier_blueprint_path=/workspace/$(basename "$TMP")/blueprint.json"
OUT="$(RUN "$CMD")" || { echo "$OUT" >&2; fail "first run failed"; }

check() { # name cpus mem_mb
    local c="${PFX}$1"
    [ "$(docker inspect "$c" --format '{{.State.Status}}')" = "running" ] || fail "$1 not running"
    [ "$(docker inspect "$c" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')" = "$NET " ] || fail "$1 not confined to $NET"
    [ "$(docker inspect "$c" --format '{{.HostConfig.NanoCpus}}')" = "$(($2 * 1000000000))" ] || fail "$1 cpu cap mismatch"
    [ "$(docker inspect "$c" --format '{{.HostConfig.Memory}}')" = "$(($3 * 1048576))" ] || fail "$1 memory cap mismatch"
}
for n in "${NAMES[@]}"; do check "$n" "$(exp_cpu "$n")" "$(exp_mem "$n")"; done
[ "$(docker inspect "${PFX}calbs-cagis-ingress" --format '{{index .Config.Labels "kuma.io/gateway"}}')" = "enabled" ] || fail "blueprint tags not propagated as labels"

docker update --memory 4096m --memory-swap 4096m "${PFX}mkrs-k8s-workload" >/dev/null
OUT="$(RUN "$CMD")" || { echo "$OUT" >&2; fail "drift-repair run failed"; }
check mkrs-k8s-workload "$(exp_cpu mkrs-k8s-workload)" "$(exp_mem mkrs-k8s-workload)"
echo "[✓] tampered cgroup cap restored to the blueprint value"
OUT="$(RUN "$CMD")" || { echo "$OUT" >&2; fail "second run failed"; }
echo "$OUT" | grep -q "changed=0" || { echo "$OUT" >&2; fail "second run not idempotent"; }
echo "[✓] tier provisioning: 3 blueprint tiers running on the isolated network with caps, labels and idempotency passed"
