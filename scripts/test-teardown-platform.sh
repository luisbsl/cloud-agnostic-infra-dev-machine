#!/usr/bin/env bash
# Verifies the teardown playbook: check-mode safety, real eviction of a dummy container, and idempotency.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
RUN() { bash scripts/sandbox-run.sh "$1" 2>&1; }
IMAGE="cloud-agnostic-dev-sandbox:latest"
TMP="$(mktemp -d -p "$PWD")"
trap 'docker rm -f kuma-control-plane >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

OUT="$(RUN "ansible-playbook playbooks/teardown-platform.yml --check")" || { echo "$OUT" >&2; fail "--check exited non-zero"; }
echo "$OUT" | grep -q "Purge Active Platform Simulation Container Tiers" || fail "missing container deletion task"
echo "$OUT" | grep -q "Unlink Scattered Data-Plane Infrastructure Definitions" || fail "missing YAML deletion task"
[ -z "$(docker ps -a --filter ancestor=$IMAGE -q)" ] || fail "lingering sandbox container"
echo "[✓] --check passed"

# Real run against a dummy container and a throwaway manifest dir, never the real outputs.
touch "$TMP/a.yaml" "$TMP/keep.txt"
docker run -d --name kuma-control-plane --entrypoint sleep "$IMAGE" 300 >/dev/null
CMD="ansible-playbook playbooks/teardown-platform.yml -e transient_manifest_dir=/workspace/$(basename "$TMP")"
RUN "$CMD" >/dev/null || fail "real run failed"
[ -z "$(docker ps -aq --filter name=^/kuma-control-plane$)" ] || fail "container not removed"
[ ! -e "$TMP/a.yaml" ] && [ -e "$TMP/keep.txt" ] || fail "manifest cleanup incorrect"
RUN "$CMD" | grep -q "changed=0" || fail "second run not idempotent"
echo "[✓] real run and idempotency passed"
