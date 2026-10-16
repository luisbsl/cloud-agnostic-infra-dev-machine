# Operational Excellence: Integrated GitHub-Actions-Like Local Pipeline

- **Status:** Architecture Blueprint Approved
- **Target File Path:** `docs/operations/06-ci-pipeline-automation.md`
- **Primary Objectives:** Standardize localized continuous integration loops, replace ad-hoc manual script execution, and maintain absolute structural parity between developer workspaces and remote actions runners.
- **Governance Alignment:** [ADR-0004](docs/adr/0004-standardize-ansible-as-unified-idempotent-orchestration-engine.md), [ADR-0005](docs/adr/0005-adopt-containerized-sandbox-dev-environment.md).

---

## 1. Non-Interactive Automation Script Engine

The framework implements a consolidated wrapper engine (`scripts/run-ci-pipeline.sh`) designed to run natively inside the decoupled sandbox. It tracks step results dynamically and outputs a standardized JUnit/TAP style logging interface to stdout.

### 1.1 Structural Handling of Failures and Tearing Down States

If any step inside a designated stage fails, the script captures the non-zero exit code, automatically stops dependent steps from processing, and hooks directly into `playbooks/teardown-platform.yml` to flush lingering test containers, preserving a scale-to-zero workstation profile.
