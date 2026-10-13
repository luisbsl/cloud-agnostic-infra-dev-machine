# Operational Excellence: Software Requirements & Dependency Mapping Matrix

This document provides the canonical specification for all local developer machine software requirements, runtime dependencies, and Ansible orchestration components required to run the platform simulation.

## 1. Exclusive Decoupled Sandbox Execution Mode & Workstation Prerequisites

To guarantee absolute predictability and zero host workstation drift, the platform enforces a single, uniform execution strategy:

- **Decoupled Sandbox Mode (`docker+ansible`) [MANDATORY]:** Runs the entire orchestration suite inside an OCI container (`Dockerfile.dev-sandbox`). Requires **ONLY** Docker Engine, POSIX Shell, and Git on the host machine. All native host execution loops have been completely purged from the repository.

### Host Hardware Sizing Limits

- **Minimum Physical Hardware:** 4 Cores, 8 GB RAM, 40 GB Free Disk Space.
- **Recommended Host Profile:** 22 Cores, 30 GB RAM, 197 GB Free Disk Space.
- **Aggregate Container Ceiling:** Clamped strictly to **8 vCPUs and 16 GB RAM** across all active tiers.
- **Idle State Sizing:** Scales completely down to **0 vCPUs and 0 GB RAM** when the sandbox container is not processing configuration tasks.

## 2. Dependency Mapping Matrix

| Dependency Name      | Binary / Command           | Min Version  | Decoupled Sandbox Requirement | Native Host Requirement | Purpose / Function                                        |
| :------------------- | :------------------------- | :----------- | :---------------------------- | :---------------------- | :-------------------------------------------------------- |
| **Container Engine** | `docker`                   | 24.0+        | **Required on Host**          | _Not Authorized_        | Host container execution runtime for platform tiers.      |
| **POSIX Shell**      | `bash` / `sh`              | 4.0+ / POSIX | **Required on Host**          | _Not Authorized_        | Host profiling and wrapper script drivers.                |
| **Git SCM**          | `git`                      | 2.30+        | **Required on Host**          | _Not Authorized_        | SCM branching and whitespace diff validation.             |
| **Python Runtime**   | `python3`                  | 3.12+        | Embedded in Sandbox Container | _Not Authorized_        | Powers Ansible core engine and requirement parsing.       |
| **JQ Processor**     | `jq`                       | 1.8.2        | Embedded in Sandbox Container | _Not Authorized_        | Validates blueprints and renders dry dataplane manifests. |
| **GitHub CLI**       | `gh`                       | 2.101.0      | Embedded in Sandbox Container | _Not Authorized_        | Applies repository rulesets and inspects remote CI runs.  |
| **Ansible Engine**   | `ansible-core`             | 2.21.5       | Embedded in Sandbox Container | _Not Authorized_        | Top-level idempotent orchestration control plane.         |
| **Ansible Galaxy**   | `ansible-galaxy`           | 2.21.5       | Embedded in Sandbox Container | _Not Authorized_        | Downloads and manages declarative Ansible collections.    |
| **PyYAML Package**   | `python3 -c "import yaml"` | 6.0+         | Embedded in Sandbox Container | _Not Authorized_        | Validates structured Ansible requirements files.          |
| **community.docker** | `ansible-galaxy`           | 5.4.0+       | Embedded in Sandbox Container | _Not Authorized_        | Declarative Ansible container lifecycle driver.           |

## 3. Automated Pre-Flight Verification

Verify host machine readiness prior to bootstrapping:

```bash
# Audit local host software dependencies for sandbox execution compatibility
bash scripts/check-requirements.sh
```
