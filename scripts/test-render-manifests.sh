#!/bin/sh
# Verifies renderer lifecycle: directory creation, stale purge and POSIX syntax.
set -eu

BLUEPRINT="blueprints/platform-services.json"
SCRIPT="scripts/render-manifests.sh"
WORK="${TMPDIR:-/tmp}/render-test.$$"
mkdir "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

fail() { echo "[x] $1" >&2; exit 1; }

sh -n "$SCRIPT" || fail "syntax check failed"

NEW="$WORK/transient-test"
[ ! -e "$NEW" ] || fail "precondition: directory exists"
sh "$SCRIPT" "$BLUEPRINT" "$NEW/" >/dev/null || fail "render into new directory failed"
[ -f "$NEW/eccs-compute-nodes.yaml" ] || fail "missing output in created directory"

OUT="$WORK/dataplanes"
mkdir "$OUT"
echo stale > "$OUT/obsolete-service.yaml"
sh "$SCRIPT" "$BLUEPRINT" "$OUT" >/dev/null || fail "render with stale file failed"
[ ! -e "$OUT/obsolete-service.yaml" ] || fail "stale manifest was not purged"
[ -f "$OUT/eccs-compute-nodes.yaml" ] || fail "missing active manifest"

echo "[✓] Renderer lifecycle tests passed"
