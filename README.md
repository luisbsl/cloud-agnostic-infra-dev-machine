# Decoupled Multi-Tier Cloud-Agnostic Kubernetes Platform Simulation

This repository defines and delivers a reproducible, local managed Kubernetes service simulation provisioned entirely as code.

To ensure complete decoupling from the developer workstation host, the architecture isolates every layer of the platform ecosystem. Infrastructure execution is managed via **Idempotent Ansible Playbooks** that coordinate our **"Dry" Render Manifest Pipeline** and enforce a strict **16 GB RAM and 8 Cores** maximum resource barrier. Network resources are abstracted using a zero-trust **CNCF Kuma Universal SDN Fabric** representing an isolated virtual multi-tenant cloud VPC, while repository security bounds are asserted via **GitHub CLI & API-Driven Declarative Rulesets**, guaranteeing an authentic cloud platform simulation completely free from vendor lock-in.

## 🪪 Repository Metadata Baselines

- **Project License Type**: Open-Source [MIT License](LICENSE) Compliance Core.
- **Principal Local Committer**: **Luis Ismael Lima** ([luisbsl@gmail.com](mailto:luisbsl@gmail.com)).
- **Target Repository Link**: `luisbsl/cloud-agnostic-infra-dev-machine`.

## 🏗️ Well-Architected Framework Interface Map

Navigate the system components using the decoupled engineering logs below:

### 1. [Architecture Foundations](docs/architecture/01-foundations.md)

- **[Mission & Elastic Limits](docs/architecture/01-foundations.md)**: Details the 100% decoupling mandate and defines the **16 GB RAM / 8 Cores** maximum resource constraints audited via Ansible.
- **[Target Interface Layout Map](docs/architecture/02-target-layout.md)**: Details structural sizing metrics, port definitions, and physical adapter isolation topologies.
- **[Target System Design Blueprint](docs/architecture/03-system-design.md)**: Conceptual component block schema and step-by-step technical processing flow charted using Mermaid.

### 2. [Operational Excellence](docs/operations/01-bootstrap.md)

- **[Multi-Tier Bootstrap Runbooks](docs/operations/01-bootstrap.md)**: Procedures for executing the unified **Ansible Playbook orchestration layer**, compiling templates, and pushing **Declarative GitHub Rulesets** via the `gh api`.
- **[Validation & Evacuation Frameworks](docs/operations/02-validation.md)**: Verification workflows for software-defined data-plane tracking and terminal-driven `gh workflow` remote testing checks.

### 3. [Security & Governance](docs/governance/01-secrets-state.md)

- **[Secrets & State Abstraction](docs/governance/01-secrets-state.md)**: Governs state persistence engines and insulates credentials modules.
- **[Agnostic Contribution Matrices](docs/governance/02-contributions.md)**: Lightweight Gitflow rules managed via [Git Workflow](docs/versioning/git-workflow.md) and artificial intelligence usage constraints for GitHub Copilot under [ADR-0003](docs/adr/0003-adopt-lightweight-gitflow-contribution-workflow.md).
