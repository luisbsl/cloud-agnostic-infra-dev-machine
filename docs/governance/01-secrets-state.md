# Security & Governance: Secrets and State Abstraction

## 1. Invariant State Protection Rules

- Treat local state maps (`*.tfstate`), plan cache files, and compiled container connection specifications as high-risk, sensitive objects.
- Enforce `sensitive = true` flags across all parameter schemas inside the platform services definition layer.
- Never check passwords, Kuma mTLS root authority keys, or security tokens into source control.

## 2. Decoupled Datastore Integration Policy

External persistent datastores are treated as pluggable, platform-agnostic abstraction boundaries. The architecture utilizes pure connection-string parameter injections, enabling system workloads to toggle seamlessly between multi-tenant public clouds and local containerized relational/non-relational datastores without modifying core repository manifests or compiled templates.
