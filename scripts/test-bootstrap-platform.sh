#!/usr/bin/env bash
# Verifies the bootstrap pre-flight capacity guardrail (passing and violating scenarios) via the sandbox wrapper.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }

for f in scripts/profile-host.sh scripts/sandbox-run.sh; do
    [ -x "$f" ] || fail "Background check failed: $f missing or not executable"
done
[ -f playbooks/bootstrap-platform.yml ] || fail "playbooks/bootstrap-platform.yml missing"

echo "[•] Scenario 1: passing invariants (--check --tags=render)"
OUT="$(bash scripts/sandbox-run.sh "ansible-playbook playbooks/bootstrap-platform.yml --check --tags=render" 2>&1)" \
    || { echo "$OUT" >&2; fail "Scenario 1 failed: non-zero exit"; }
echo "$OUT" | grep -q "Pre-flight bounds check passed" || fail "Scenario 1 failed: missing bounds-check log"
echo "$OUT" | grep -q "Pre-flight resource monitoring check passed" || fail "Scenario 1 failed: missing monitoring log"
[ -z "$(docker ps -a --filter ancestor=cloud-agnostic-dev-sandbox:latest -q)" ] || fail "Scenario 1 failed: lingering container"
echo "[✓] Scenario 1 passed"

echo "[•] Scenario 2: ceiling violation must halt"
set +e
OUT="$(bash scripts/sandbox-run.sh "ansible-playbook playbooks/bootstrap-platform.yml --check --tags=render -e capacity_ceiling_cpu=4" 2>&1)"
RC=$?
set -e
[ "$RC" -ne 0 ] || fail "Scenario 2 failed: playbook did not halt"
echo "$OUT" | grep -q "Hardware boundary violation" || fail "Scenario 2 failed: missing violation message"
[ -z "$(docker ps -a --filter ancestor=cloud-agnostic-dev-sandbox:latest -q)" ] || fail "Scenario 2 failed: lingering container"
echo "[✓] Scenario 2 passed"

echo "[•] Scenario Outline: isolated task selection via tags"
ALL_COMPONENTS="Trigger Manifest Engine|Computing Fabric Tiers|Software-Defined Network|Declarative Rulesets API"
check_tag() {
    local tag="$1" expected="$2" out
    out="$(bash scripts/sandbox-run.sh "ansible-playbook playbooks/bootstrap-platform.yml --check --tags=$tag" 2>&1)" \
        || { echo "$out" >&2; fail "Tag '$tag' failed: non-zero exit"; }
    echo "$out" | grep -q "TASK \[.*$expected" || fail "Tag '$tag': missing component '$expected'"
    if echo "$out" | grep "TASK \[" | grep -E "$ALL_COMPONENTS" | grep -vq "$expected"; then
        fail "Tag '$tag': executed components outside '$expected'"
    fi
    [ -z "$(docker ps -a --filter ancestor=cloud-agnostic-dev-sandbox:latest -q)" ] || fail "Tag '$tag': lingering container"
    echo "[✓] Tag '$tag' isolated to '$expected'"
}
check_tag render "Trigger Manifest Engine"
check_tag compute "Computing Fabric Tiers"
check_tag networking "Software-Defined Network"
check_tag github-setup "Declarative Rulesets API"
