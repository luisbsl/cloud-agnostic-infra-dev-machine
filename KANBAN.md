# 📋 Copilot AI-Driven Dynamic Kanban Board

**Active Focus Boundary:** Milestone 02: Live Container Orchestration & Kuma SDN Fabric Integration
**Last Matrix Compilation:** 2026-10-13 23:32:04

<details><summary>🏁 Milestone 01: Core Blueprint Schema, Render Pipeline & Ansible Orchestration Foundation — Completed</summary>

| 🟥 BACKLOG / TODO | 🟨 IN PROGRESS | 🟩 DONE (VERIFIED IN DEV/DEVELOP) |
| :--- | :--- | :--- |
| | | **Epic 1**: **Story 1.1**: Define the JSON schema for Tier 1 (ECCS), Tier 2/3 (Ingress/Gateway), and Tier 4 (Kubernetes Workloads). |
| | | **Epic 1**: **Story 1.2**: Embed Kuma SDN metadata tags (`kuma.io/service`, `tier`, `mesh`) directly into abstract service declarations. |
| | | **Epic 2**: **Story 2.1**: Implement a shell script that ingests `blueprints/platform-services.json` and compiles transient, tagged deployment files into `docs/compiled-manifests/dataplanes/`. |
| | | **Epic 2**: **Story 2.2**: Ensure directory creation, clean teardown of stale transients, and strict POSIX compliance. |
| | | **Epic 3**: **Story 3.1**: Define `playbooks/requirements.yml` declaring required collections (`community.docker`) to manage system container nodes. |
| | | **Epic 3**: **Story 3.2**: Implement `playbooks/bootstrap-platform.yml` embedded with capacity assertion tasks that invoke `scripts/profile-host.sh` within the container context to guarantee resource limits do not break the 16 GB RAM and 8 vCPUs workspace bounds. |
| | | **Epic 3**: **Story 3.3**: Configure Ansible task tagging parameters (`render`, `compute`, `networking`, `github-setup`) to isolate control scopes cleanly. |
| | | **Epic 4**: **Story 4.1**: Create non-destructive validation playbooks (`playbooks/validate-platform.yml`) utilizing `community.docker.docker_container_info` to audit local node operational status and ensure zero-trust Kuma mesh API availability. |
| | | **Epic 4**: **Story 4.2**: Create an emergency workspace evacuation playbook (`playbooks/teardown-platform.yml`) to clear platform containers and transient file layers, reclaiming workstation capacity cleanly back to zero. |

</details>

## 🎯 Milestone 02: Live Container Orchestration & Kuma SDN Fabric Integration — Active

| 🟥 BACKLOG / TODO | 🟨 IN PROGRESS | 🟩 DONE (VERIFIED IN DEV/DEVELOP) |
| :--- | :--- | :--- |
| **Epic 1**: **Story 1.1**: Implement an Ansible task using `community.docker.docker_network` to define a dedicated bridge network named `platform-simulation-net` with MTU boundaries set to `1500`. | | |
| **Epic 1**: **Story 1.2**: Inject dynamic metadata labels into the network lifecycle layer to isolate it from external developer stack topologies. | | |
| **Epic 2**: **Story 2.1**: Implement an idempotent container allocation blueprint targeting `kuma-control-plane` using pinned components (`docker.io/kong/kuma-cp:2.9.1`). | | |
| **Epic 2**: **Story 2.2**: Build a robust `ansible.builtin.uri` validation loop that queries the API endpoint `http://localhost:5681/meshes` with an exponential backoff retry mechanism (Max 10 attempts). | | |
| **Epic 3**: **Story 3.1**: Implement loop routines that parse `blueprints/platform-services.json` to spawn active infrastructure workloads (`eccs-compute-nodes`, `calbs-cagis-ingress`, `mkrs-k8s-workload`). | | |
| **Epic 3**: **Story 3.2**: Explicitly map cgroup capacity caps (`cpus`, `memory_limit`) directly into the docker runtime configs to protect developer machine stability. | | |
| **Epic 4**: **Story 4.1**: Update the active platform validation suite to parse and assert Kuma Dataplane data structures on-the-fly via the live control plane catalog. | | |
| **Epic 4**: **Story 4.2**: Integrate a test assertion block to verify zero-trust path isolation between unauthenticated zones. | | |
