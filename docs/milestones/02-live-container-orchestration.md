# Milestone 02: Live Container Orchestration & Kuma SDN Fabric Integration

- **Status:** Approved / Target for Execution
- **Target File Path:** `docs/milestones/02-live-container-orchestration.md`
- **Primary Objectives:** Provision the software-defined bridge networks, deploy the Kuma SDN Control Plane container, orchestrate the tier container cgroup pools idempotently, and execute secure edge-traffic proxy validation rules.
- **Governance Alignment:** [ADR-0001](docs/adr/0001-cloud-agnostic-multi-tier-baseline.md), [ADR-0002](docs/adr/0002-kuma-universal-sdn-and-dry-render-architecture.md), [ADR-0004](docs/adr/0004-standardize-ansible-as-unified-idempotent-orchestration-engine.md), [ADR-0005](docs/adr/0005-adopt-containerized-sandbox-dev-environment.md).

---

## 1. Executive Summary & Epics

Milestone 02 transforms the declarative, compiled templates from Milestone 01 into an active multi-tier infrastructure simulation. By driving the local host Docker daemon socket through the containerized sandbox plane, it initializes an enterprise-grade SDN environment within strict hardware guardrails.

```mermaid
graph TD
    A[Epic 1: Isolated Software-Defined Network Bridge] --> B[Epic 2: Kuma SDN Control Plane Integration]
    B --> C[Epic 3: Idempotent Tier Container Provisioning]
    C --> D[Epic 4: Live Mesh Routing E2E Verification]
```

## 2. Epics & User Stories Breakdown

### Epic 1: Isolated Software-Defined Network Bridge

**Target Branch:** `infra/docker-network-fabric`
**Deliverables:** `playbooks/tasks/network-bridge.yml`

- **Story 1.1:** Implement an Ansible task using `community.docker.docker_network` to define a dedicated bridge network named `platform-simulation-net` with MTU boundaries set to `1500`.
- **Story 1.2:** Inject dynamic metadata labels into the network lifecycle layer to isolate it from external developer stack topologies.
- **Acceptance Criteria:** `docker network inspect platform-simulation-net` shows a stable network footprint.

### Epic 2: Kuma SDN Control Plane Integration

**Target Branch:** `feature/kuma-control-plane-bootstrap`
**Deliverables:** `playbooks/tasks/kuma-cp-core.yml`

- **Story 2.1:** Implement an idempotent container allocation blueprint targeting `kuma-control-plane` using pinned components (`docker.io/kong/kuma-cp:2.9.1`).
- **Story 2.2:** Build a robust `ansible.builtin.uri` validation loop that queries the API endpoint `http://localhost:5681/meshes` with an exponential backoff retry mechanism (Max 10 attempts).
- **Acceptance Criteria:** The playbook continues execution only after receiving an HTTP status code `200` from the Kuma API.

### Epic 3: Idempotent Tier Container Provisioning

**Target Branch:** `infra/tier-container-orchestration`
**Deliverables:** `playbooks/tasks/provision-tiers.yml`

- **Story 3.1:** Implement loop routines that parse `blueprints/platform-services.json` to spawn active infrastructure workloads (`eccs-compute-nodes`, `calbs-cagis-ingress`, `mkrs-k8s-workload`).
- **Story 3.2:** Explicitly map cgroup capacity caps (`cpus`, `memory_limit`) directly into the docker runtime configs to protect developer machine stability.
- **Acceptance Criteria:** All containers report a state of `running` and match their allocated resource constraints exactly.

### Epic 4: Live Mesh Routing E2E Verification

**Target Branch:** `feature/mesh-routing-validation`
**Deliverables:** `playbooks/validate-platform.yml` (Updated)

- **Story 4.1:** Update the active platform validation suite to parse and assert Kuma Dataplane data structures on-the-fly via the live control plane catalog.
- **Story 4.2:** Integrate a test assertion block to verify zero-trust path isolation between unauthenticated zones.
- **Acceptance Criteria:** Executing `ansible-playbook playbooks/validate-platform.yml` successfully completes all validation checks with zero task failures.

---

## 4. Operational Execution Sequence & PR Flow

````bash
# 1. Initialize Git branch context from develop
git switch develop
git pull --ff-only origin develop
git switch -c infra/docker-network-fabric

# 2. Trigger Local Pre-Flight Checks to guarantee baseline health
bash scripts/sandbox-run.sh "jq empty docs/compiled-manifests/governance/protect-gitflow.json"
bash scripts/sandbox-run.sh "bash scripts/validate-blueprint.sh blueprints/platform-services.json"
bash scripts/sandbox-run.sh "sh scripts/render-manifests.sh && sh scripts/test-render-manifests.sh"
git diff --check

# 3. Stage changes, perform cached whitespace checks, and commit under Conventional guidelines
git add playbooks/tasks/network-bridge.yml
git diff --cached --check
git commit -m "infra: implement software-defined docker bridge network fabric for Epic 1"

4. Open Pull Request and stream remote CI status gates via GitHub CLI

```bash
git push --set-upstream origin infra/docker-network-fabric
gh pr create --base develop --title "infra: implement software-defined docker network bridge" --body "Delivers Epic 1 for Milestone 02."
gh pr checks --watch --fail-fast
````

5. Execute explicit merge commits and synchronize local branch tracking points

```bash
gh pr merge --merge --delete-branch
git switch develop
git pull --ff-only origin develop
```
