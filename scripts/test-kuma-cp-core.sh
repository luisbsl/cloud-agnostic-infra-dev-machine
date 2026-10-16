#!/usr/bin/env bash
# Verifies playbooks/tasks/kuma-cp-core.yml: pinned image, network confinement, cgroup caps, loopback port, idempotency.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
RUN() { bash scripts/sandbox-run.sh "$1" 2>&1; }
NET="platform-simulation-net-kuma-test"
CP="kuma-control-plane-test"
PORT=15681
IMAGE="docker.io/kong/kuma-cp:2.9.1"
TMP="$(mktemp -d -p "$PWD")"
trap 'docker rm -f "$CP" >/dev/null 2>&1 || true; docker network rm "$NET" >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

cat > "$TMP/play.yml" <<'PLAY'
---
- hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - ansible.builtin.include_tasks: ../playbooks/tasks/network-bridge.yml
    - ansible.builtin.include_tasks: ../playbooks/tasks/kuma-cp-core.yml
PLAY

CMD="ansible-playbook $(basename "$TMP")/play.yml -e platform_network_name=$NET -e kuma_cp_name=$CP -e kuma_cp_host_port=$PORT"
RUN "$CMD" >/dev/null || fail "first run failed"

insp() { docker inspect "$CP" --format "$1"; }
[ "$(insp '{{.Config.Image}}')" = "$IMAGE" ] || fail "image not pinned to $IMAGE"
[ "$(insp '{{.State.Running}}')" = "true" ] || fail "container not running"
[ "$(insp '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')" = "$NET " ] || fail "container not confined to $NET"
[ "$(insp '{{.HostConfig.NanoCpus}}')" = "1000000000" ] || fail "cpu cap is not 1 core"
[ "$(insp '{{.HostConfig.Memory}}')" = "2147483648" ] || fail "memory cap is not 2048 MB"
[ "$(insp '{{(index (index .NetworkSettings.Ports "5681/tcp") 0).HostIp}}:{{(index (index .NetworkSettings.Ports "5681/tcp") 0).HostPort}}')" = "127.0.0.1:$PORT" ] || fail "port not bound to 127.0.0.1:$PORT"

RUN "$CMD" | grep -q "changed=0" || fail "second run not idempotent"
echo "[✓] kuma control plane: pinned image, network confinement, 1 CPU/2048 MB caps, loopback port and idempotency passed"
