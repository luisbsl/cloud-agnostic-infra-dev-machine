# Security & Governance: Managed Platform Contribution Matrix

## 1. Change Integration Flow

This repository implements a lightweight Gitflow delivery framework. All development tasks, configuration modifications, and architectural updates must strictly follow the branch strategies, naming conventions, and review loops detailed in the operational blueprint: [Git Workflow](../versioning/git-workflow.md).

Merges are performed exclusively via traditional merge commits to preserve historical alignment. Direct pushes to protected branches (`main` and `develop`) are structurally blocked by repository rulesets as defined in [ADR-0003](../adr/0003-adopt-lightweight-gitflow-contribution-workflow.md).

## 2. GitHub Copilot Engineering Constraints

- Copilot acts as an execution aid for generating cloud-agnostic manifest profiles. It is never an automated deployment authority.
- Automated agents are strictly barred from invoking live cluster executions (`terraform apply`, `kumactl apply`) without active human verification.
- Real system tokens, production configurations, and decryption keys must never be exposed to LLM context layers.
