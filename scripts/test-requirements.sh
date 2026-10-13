#!/bin/sh
# Verifies the Galaxy requirements file structure and that it resolves, without touching host collections.
# ansible-galaxy has no --dry-run flag, so the install targets a throwaway path.
set -eu

FILE="${1:-playbooks/requirements.yml}"
WORK="${TMPDIR:-/tmp}/galaxy-test.$$"
mkdir "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

command -v ansible-galaxy >/dev/null 2>&1 || { echo "[x] ansible-galaxy is required" >&2; exit 1; }

python3 - "$FILE" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
cols = data.get("collections") if isinstance(data, dict) else None
if not isinstance(cols, list):
    sys.exit("[x] missing top-level 'collections' list")
if not any(isinstance(c, dict) and c.get("name") == "community.docker" for c in cols):
    sys.exit("[x] 'community.docker' not declared in collections")
PY

# --force avoids the "Nothing to do" short-circuit when a bundled copy exists on the host.
OUT="$(ansible-galaxy collection install -r "$FILE" -p "$WORK" --force 2>&1)" || { echo "$OUT" >&2; exit 1; }
echo "$OUT" | grep -q "community.docker" || { echo "[x] community.docker was not resolved" >&2; exit 1; }

echo "[✓] Requirements valid; community.docker resolved"
