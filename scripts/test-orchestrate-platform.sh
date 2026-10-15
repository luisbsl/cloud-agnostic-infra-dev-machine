#!/usr/bin/env bash
# Live end-to-end acceptance for Milestone 02: orchestrate-platform.yml must bring up the real stack, a second run must
# be idempotent (changed=0), validate-platform.yml must pass against the live Kuma control plane, and breaking the
# zero-trust posture or a Dataplane token must make validation fail. Uses the real resource names and port 5681,
# so it refuses to run when they are already in use.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
RUN() { bash scripts/sandbox-run.sh "$1" 2>&1; }
NAMES="kuma-control-plane eccs-compute-nodes calbs-cagis-ingress mkrs-k8s-workload"

for n in $NAMES; do
    [ -z "$(docker ps -aq --filter "name=^${n}$")" ] || fail "$n already exists; run playbooks/teardown-platform.yml first"
done
docker network inspect platform-simulation-net >/dev/null 2>&1 && fail "platform-simulation-net already exists; run playbooks/teardown-platform.yml first"
TMP="$(mktemp -d -p "$PWD")"
trap 'docker rm -f $NAMES >/dev/null 2>&1 || true; docker network rm platform-simulation-net >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

# Docker rejects CPU caps above the daemon CPU count (e.g. 4-vCPU CI runners); clamp only the provisioning copy then.
EXTRA=""
NCPU="$(docker info --format '{{.NCPU}}')"
if [ "$NCPU" -lt "$(jq '[.services[].resources.cpu] | max' blueprints/platform-services.json)" ]; then
    jq --argjson n "$NCPU" '.services |= map(.resources.cpu |= (if . > $n then $n else . end))' blueprints/platform-services.json > "$TMP/blueprint.json"
    EXTRA=" -e tier_blueprint_path=/workspace/$(basename "$TMP")/blueprint.json"
    echo "[!] daemon exposes $NCPU CPUs; provisioning with a clamped blueprint copy"
fi

OUT="$(RUN "ansible-playbook playbooks/orchestrate-platform.yml$EXTRA")" || { echo "$OUT" >&2; fail "orchestration failed"; }
echo "$OUT" | grep -Eq "failed=0" || fail "orchestration reported failures"
echo "[✓] stack orchestrated"

OUT="$(RUN "ansible-playbook playbooks/orchestrate-platform.yml$EXTRA")" || { echo "$OUT" >&2; fail "second orchestration failed"; }
echo "$OUT" | grep -q "changed=0" || { echo "$OUT" | tail -5 >&2; fail "orchestration is not idempotent"; }
echo "[✓] second run idempotent (changed=0)"

OUT="$(RUN "ansible-playbook playbooks/validate-platform.yml")" || { echo "$OUT" >&2; fail "validate-platform failed against the live stack"; }
echo "$OUT" | grep -q "failed=0" || fail "validation reported failures"
for n in eccs-compute-nodes calbs-cagis-ingress mkrs-k8s-workload; do
    echo "$OUT" | grep -q "Verified Dataplane $n" || fail "$n Dataplane not verified live"
done
echo "$OUT" | grep -q "rejected (non-mTLS path blocked)" || fail "plaintext isolation not verified live"
echo "$OUT" | grep -q "Validation summary: .* failures=0" || fail "final summary missing"
echo "[✓] validate-platform passes live with zero failures"

# Negative: an allow-all TrafficPermission must be caught.
curl -sf -X PUT http://localhost:5681/meshes/platform-simulation-vpc/traffic-permissions/allow-all -H 'content-type: application/json' \
    -d '{"type":"TrafficPermission","name":"allow-all","mesh":"platform-simulation-vpc","sources":[{"match":{"kuma.io/service":"*"}}],"destinations":[{"match":{"kuma.io/service":"*"}}]}' >/dev/null \
    || fail "could not inject allow-all permission"
OUT="$(RUN "ansible-playbook playbooks/validate-platform.yml" || true)"
echo "$OUT" | grep -q "allow-all TrafficPermission present: allow-all" || fail "live allow-all permission not detected"
curl -sf -X DELETE http://localhost:5681/meshes/platform-simulation-vpc/traffic-permissions/allow-all >/dev/null
echo "[✓] live allow-all permission detected"

# Negative: a drifted kuma.io/service token must be caught.
curl -sf -X PUT http://localhost:5681/meshes/platform-simulation-vpc/dataplanes/mkrs-k8s-workload -H 'content-type: application/json' \
    -d '{"type":"Dataplane","name":"mkrs-k8s-workload","mesh":"platform-simulation-vpc","networking":{"address":"127.0.0.1","inbound":[{"port":8080,"tags":{"kuma.io/service":"drifted-svc"}}]}}' >/dev/null \
    || fail "could not inject drifted dataplane"
OUT="$(RUN "ansible-playbook playbooks/validate-platform.yml" || true)"
echo "$OUT" | grep -q "blueprint expects mkrs-workload-svc" || fail "live token drift not detected"
echo "[✓] live kuma.io/service drift detected"
echo "[✓] Milestone 02 live end-to-end acceptance passed"
