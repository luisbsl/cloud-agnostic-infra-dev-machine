# ADR-0005: Adopt Ephemeral Containerized Control Plane Sandbox for Dev Machine Decoupling

- **Status:** Accepted
- **Date:** 2026-10-11
- **Decision Scope:** Local Developer Machine Tooling & Orchestration Isolation
- **Related Documents:** [ADR-0001](0001-cloud-agnostic-multi-tier-baseline.md), [ADR-0004](0004-standardize-ansible-as-unified-idempotent-orchestration-engine.md), [Software Requirements Mapping Matrix](../operations/03-dependencies.md)

## Context

Executing Ansible playbooks, compiling JSON blueprints, and validating GitHub rulesets directly on developer workstations traditionally required maintaining a native ecosystem of core binaries. This toolchain dependency led to workstation drift, package version incompatibilities across Linux/macOS targets, and complex developer onboarding requirements. A dual-execution compromise left configurations vulnerable to host-level drift.

## Decision

1. **Mandate Exclusive Decoupled Sandbox Execution:** Purge all native host execution workflows. The containerized sandbox is the sole authorized strategy for local orchestration, manifest rendering, and ecosystem configuration.
2. **Establish Containerized Control Plane Sandbox:** Encapsulate the entire platform toolchain into a lightweight standard OCI image (`Dockerfile.dev-sandbox`) pinned to verified October 2026 stable components:
   - **Base OS:** Alpine Linux 3.24.2
   - **Automation Control Plane:** Ansible-Core 2.21.5
   - **JSON Processor:** JQ 1.8.2
   - **Platform Interface:** GitHub CLI 2.101.0
3. **Mount Host Docker Daemon Socket:** Bind-mount the host's `/var/run/docker.sock` and workspace repository (`$PWD:/workspace`) into the sandbox container. This enables Ansible inside the container to orchestrate and provision infrastructure tiers (ECCS, CALBS, MKRS) directly on the host Docker daemon.
4. **Enforce Strict Scale-to-Zero Idle Behavior:** Design the sandbox orchestration wrapper (`scripts/sandbox-run.sh`) to execute tasks via transient, ephemeral runtime cycles (`docker run --rm`). When commands finish or interactive terminal sessions are terminated, the container terminates immediately, scaling host memory and CPU utilization to absolute zero.
5. **Minimize Host Prerequisites:** Reduce workstation software requirements down to three immutable system dependencies:
   - **Container Engine:** Docker Desktop / Docker Engine 24.0+
   - **POSIX Shell:** `/bin/sh` or `/usr/bin/env bash`
   - **SCM:** Git 2.30+

## Consequences

- **Positive:** Reduces workstation setup time from 30 minutes to seconds.
- **Positive:** Guarantees 100% deterministic executions across Linux and macOS workstations.
- **Positive:** Insulates developer workstation hosts from Python package pollution or library drift.
- **Positive:** Guarantees an idle resource consumption footprint of absolute zero when no tasks are running.
- **Negative:** Requires Docker daemon socket access on developer workstations.
