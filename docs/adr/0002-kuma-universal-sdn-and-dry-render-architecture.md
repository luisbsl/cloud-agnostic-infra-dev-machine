# ADR-0002: Kuma Universal SDN and "Dry" Render Manifest Pipeline Integration

- **Status:** Accepted
- **Date:** 2026-10-05
- **Decision Scope:** SDN Fabric, Virtual VPC Topology, and Sidecar Orchestration
- **Related Document:** [Target Layout Map](../architecture/02-target-layout.md)

## Context

Traditional user-space network encapsulation and heavy state quorums introduce unnecessary maintenance friction and risk host-level route collisions. Transitioning to a modern Software-Defined Network (SDN) like Kuma (by Kong) provides elegant logical VPC isolation (`Mesh`), but introduces an operational requirement to maintain complex, vendor-specific tag definitions for every container proxy sidecar definition.

## Decision

1. **Adopt Kuma as Central SDN Fabric:** Implement Kuma (by Kong) as the universal, platform-agnostic network control plane to simulate an isolated multi-tenant VPC cloud network.
2. **Establish Isolated Virtual VPCs via Meshes:** Enforce absolute network isolation by partitioning environments into distinct logical `Mesh` buckets on the control plane, blocking inter-mesh data paths by default.
3. **Implement Pattern 2 (The "Dry" Render Pipeline):** Completely decouple developer workstation components from direct Kuma tool dependencies. Developers define core infrastructure services using generic, vendor-agnostic blueprint configuration structures (`platform-services.json`).
4. **Compile Sidecar Tag Infrastructure On-Demand:** Utilize a local compilation rendering script (`render-manifests.sh`) to combine the abstract blueprints with Kuma template blocks. This generates the transient, tagged container metadata files (`kuma.io/service`, `tier`) on-the-fly, preventing syntax leakage into core manifests.

## Consequences

- **Positive:** Replaces physical subnet planning with zero-trust, identity-based microsegmentation and automated mutual TLS (mTLS).
- **Positive:** Protects the developer workspace from third-party binary tool footprints and vendor lock-in.
- **Positive:** Enables pre-flight static verification of compiled manifest files before deployment execution.
- **Negative:** Introduces a required template rendering stage into the local platform initialization runbook.
