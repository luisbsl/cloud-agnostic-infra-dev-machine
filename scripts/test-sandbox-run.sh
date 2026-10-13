#!/usr/bin/env bash
# Verifies containerized sandbox command execution, proxying, and scale-to-zero cleanup.
# Validates the Gherkin feature: Containerized Sandbox Command Execution and Scope Verification.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }

echo "================================================================="
echo "  SANDBOX WRAPPER SPECIFICATION & GHERKIN STORY VERIFICATION     "
echo "================================================================="

# Background assertions
[ -f "scripts/sandbox-run.sh" ] || fail "Background check failed: scripts/sandbox-run.sh does not exist"
[ -x "scripts/sandbox-run.sh" ] || fail "Background check failed: scripts/sandbox-run.sh is not executable"
[ -f "Dockerfile.dev-sandbox" ] || fail "Background check failed: Dockerfile.dev-sandbox does not exist"
grep -q -- "--rm" scripts/sandbox-run.sh || fail "Wrapper missing mandatory --rm automatic cleanup flag"

echo "[✓] Background preconditions verified: wrapper exists, executable flags set, Dockerfile present."

# Scenario 1: Execute Operational Command Through Sandbox Wrapper
echo "[•] Scenario 1: Executing operational verification command via sandbox wrapper..."
OUTPUT=$(bash scripts/sandbox-run.sh "echo Sandbox-Verification-Success")
echo "    Stdout received: $OUTPUT"

echo "$OUTPUT" | grep -q "Sandbox-Verification-Success" || fail "Scenario 1 failed: stdout stream missing verification marker"

LINGERING=$(docker ps -a --filter "ancestor=cloud-agnostic-dev-sandbox:latest" -q)
if [ -n "$LINGERING" ]; then
    fail "Scenario 1 failed: lingering container instances detected: $LINGERING"
fi
echo "[✓] Scenario 1 passed: exit code 0, stdout matched, automatic --rm purge confirmed, idle footprint at zero."

# Scenario 2: Catch and Proxy Inner Command Non-Zero Exit Codes
echo "[•] Scenario 2: Executing failing inner command to verify error code proxying..."
set +e
FAIL_OUTPUT=$(bash scripts/sandbox-run.sh "ls non_existent_blueprint_file.json" 2>&1)
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -eq 0 ]; then
    fail "Scenario 2 failed: expected non-zero exit code from failing inner command, but got 0"
fi
echo "    Inner command exited with code: $EXIT_CODE (non-zero as expected)"

LINGERING_AFTER_FAIL=$(docker ps -a --filter "ancestor=cloud-agnostic-dev-sandbox:latest" -q)
if [ -n "$LINGERING_AFTER_FAIL" ]; then
    fail "Scenario 2 failed: container overlay not purged after failure: $LINGERING_AFTER_FAIL"
fi
echo "[✓] Scenario 2 passed: non-zero exit code proxied cleanly, container purged immediately from memory space."

echo "================================================================="
echo "[✓] GHERKIN FEATURE VERIFICATION COMPLETE: ALL SCENARIOS PASSED"
echo "================================================================="
