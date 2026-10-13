#!/usr/bin/env bash
# Verifies the non-destructive topology/SDN validation playbook via the sandbox wrapper.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }

for f in scripts/sandbox-run.sh scripts/validate-blueprint.sh; do
    [ -f "$f" ] || fail "Background check failed: $f missing"
done
[ -f docs/milestones/01-foundation-and-dry-render-pipeline.md ] || fail "Milestone document missing"

OUT="$(bash scripts/sandbox-run.sh "ansible-playbook playbooks/validate-platform.yml --check" 2>&1)" \
    || { echo "$OUT" >&2; fail "validate-platform --check exited non-zero"; }
for n in eccs-compute-nodes calbs-cagis-ingress mkrs-k8s-workload; do
    echo "$OUT" | grep -q "$n" || fail "stdout missing check for $n"
done
[ -z "$(docker ps -a --filter ancestor=cloud-agnostic-dev-sandbox:latest -q)" ] || fail "lingering sandbox container"
echo "[✓] validate-platform --check passed; sandbox scaled to zero"
