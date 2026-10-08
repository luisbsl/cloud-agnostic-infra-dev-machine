#!/usr/bin/env bash
# Asserts schema, tier, resource-ceiling and Kuma tag invariants of the platform blueprint.
set -euo pipefail

FILE="${1:-blueprints/platform-services.json}"

jq empty "$FILE"

jq -e '
  def svc($n): .services[] | select(.name == $n);
  .schemaVersion == "1.0.0"
  and .mesh == "platform-simulation-vpc"
  and (svc("eccs-compute-nodes")  | .tier == "tier-1-eccs" and .resources.cpu <= 6
       and .tags["kuma.io/service"] == "eccs-compute-svc")
  and (svc("calbs-cagis-ingress") | .tier == "tier-2-3-ingress-gateway" and .resources.cpu <= 1
       and .tags["kuma.io/service"] == "ingress-gateway-svc")
  and (svc("mkrs-k8s-workload")   | .tier == "tier-4-mkrs-workload" and .resources.cpu <= 1
       and .tags["kuma.io/service"] == "mkrs-workload-svc")
  and ([.services[].resources.cpu] | add) <= 8
  and ([.services[].resources.ramGb] | add) <= 16
  and (.services | all(.tags.mesh == "platform-simulation-vpc"))
' "$FILE" >/dev/null || { echo "Blueprint assertions failed for $FILE" >&2; exit 1; }

echo "Blueprint $FILE is valid."
