# ADR-0004: Standardize Ansible as the Unified Idempotent Orchestration Engine

- **Status:** Accepted
- **Date:** 2026-10-05
- **Decision Scope:** Configuration Management and Local Playbook Orchestration
- **Related Documents:** [Bootstrap Runbook](../operations/01-bootstrap.md), [Validation Framework](../operations/02-validation.md)

## Context

Executing multi-tier infrastructure configurations across developer workstations using basic shell scripts induces high rates of configuration drift. Imperative shell tools lack built-in state verification mechanisms, leading to duplicate allocation faults, memory-clamping failures, or orphaned system container instances when execution loops crash mid-run. To meet our strict capacity thresholds (8 vCPUs and 16 GB RAM), our local runbooks require a declarative, state-aware automation system.

## Decision

1. **Adopt Ansible as Central Workflow Controller:** Standardize on Ansible as the top-level orchestration tool for all local environment setups, runtime validations, and environment teardown playbooks.
2. **Enforce Pre-Flight Resource Assertions:** Implement mandatory Ansible assertion modules at the start of all playbooks. These tasks audit workstation capacities to ensure dynamic cgroup allocations can fit cleanly inside resource limits.
3. **Isolate Lifecycle Contexts with Target Tags:** Segment playbook task files using strict operational selectors (`render`, `compute`, `networking`) to allow developers to execute atomic portions of the infrastructure stack seamlessly.
4. **Abstract Engine Operations via Collections:** Delegate container state lifecycle modifications to standard declarative components (`community.docker`), avoiding custom shell loops or command bindings.

## Consequences

- **Positive:** Eliminates drift and duplicate allocation errors through native task idempotence.
- **Positive:** Provides safe execution handling, using task-rescue structures to trigger clean environment purges during fatal pipeline breaks.
- **Positive:** Leverages a lightweight footprint on the host, dropping workstation memory draw to zero once an orchestration execution block ends.
- **Negative:** Mandates that a Python interpreter and accurate pip dependency requirements exist locally on the host machine.
