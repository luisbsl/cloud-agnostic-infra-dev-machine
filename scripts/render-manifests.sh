#!/bin/sh
# Compiles the abstract service blueprint into transient Kuma Dataplane manifests.
# Usage: scripts/render-manifests.sh [blueprint.json] [output-dir]
set -eu

BLUEPRINT="${1:-blueprints/platform-services.json}"
OUT_DIR="${2:-docs/compiled-manifests/dataplanes}"

command -v jq >/dev/null 2>&1 || { echo "[x] jq is required" >&2; exit 1; }
[ -f "$BLUEPRINT" ] || { echo "[x] Blueprint not found: $BLUEPRINT" >&2; exit 1; }
jq empty "$BLUEPRINT"

mkdir -p "$OUT_DIR"
STAGE="${TMPDIR:-/tmp}/render-manifests.$$"
mkdir "$STAGE"
trap 'rm -rf "$STAGE"' EXIT INT TERM

# Renders one service as a Dataplane; gateway-enabled services get a delegated gateway block.
RENDER='
  def q: if type == "string" and test("^[A-Za-z0-9._/-]+$") then . else tojson end;
  .mesh as $default_mesh
  | .services[] | select(.name == $svc)
  | ((.tags.mesh // $default_mesh) as $mesh
    | (.tags["kuma.io/gateway"] == "enabled") as $gw
    | (.tags + {tier: .tier} | del(.mesh)) as $t
    | "type: Dataplane",
      "name: \(.name | q)",
      "mesh: \($mesh | q)",
      "networking:",
      "  address: \("{{ dataplane_address }}" | q)",
      (if $gw then "  gateway:", "    type: DELEGATED", "    tags:"
       else "  inbound:", "    - tags:" end),
      ($t | to_entries | sort_by(.key) | .[]
        | (if $gw then "      " else "        " end) + "\(.key): \(.value | q)"))
'

COUNT=0
for NAME in $(jq -r '.services[].name' "$BLUEPRINT"); do
  case "$NAME" in
    ''|*[!a-z0-9-]*|-*) echo "[x] Invalid service name: $NAME" >&2; exit 1 ;;
  esac
  jq -r --arg svc "$NAME" "$RENDER" "$BLUEPRINT" > "$STAGE/$NAME.yaml"
  [ -s "$STAGE/$NAME.yaml" ] || { echo "[x] Empty render for $NAME" >&2; exit 1; }
  COUNT=$((COUNT + 1))
done
[ "$COUNT" -gt 0 ] || { echo "[x] Blueprint declares no services" >&2; exit 1; }

# Only reached when every service rendered: drop stale output, then publish.
for STALE in "$OUT_DIR"/*.yaml; do
  [ -e "$STALE" ] && rm -f "$STALE"
done
cp "$STAGE"/*.yaml "$OUT_DIR"/

echo "[✓] Rendered $COUNT Dataplane manifest(s) into $OUT_DIR"
