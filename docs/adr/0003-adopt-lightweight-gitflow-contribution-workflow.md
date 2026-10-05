# ADR-0003: Adopt Lightweight Gitflow Contribution Workflow

- **Status:** Accepted
- **Date:** 2026-10-05
- **Decision Scope:** Version Control Strategy, Repository Governance, and API-Driven Safeguards
- **Related Documents:** [Git Workflow](../versioning/git-workflow.md), [Managed Platform Contribution Matrix](../governance/02-contributions.md)

## Context

As an infrastructure repository simulating multi-tier environments, the project requires an integration model that ensures thorough review, change stability, and immutable release snapshots without the overhead of heavy enterprise branch structures. Manual branch configuration leads to configuration drift, meaning protections must be codified and driven programmatically.

## Decision

1. **Establish Main/Develop Separation:** Adopt two long-lived branches: `main` for reviewed, stable production snapshots, and `develop` for active integration.
2. **Enforce Short-Lived Feature Branches:** Restrict all direct modifications to `main` or `develop`. Changes must flow through prefix-enforced topic branches (`feature/*`, `fix/*`, `docs/*`, `infra/*`) via pull requests.
3. **Mandate Explicit Merge Commits:** Enforce a strict repository-level prohibition on squash and rebase merges to retain complete, un-rewritten historical traceability of platform architecture modifications.
4. **Programmatic Governance via GitHub Rulesets:** Replace legacy manual branch rules with a declarative repository ruleset definition file (`protect-gitflow.json`). This configuration is pushed directly to the platform APIs using the `gh api` tool during bootstrap runs.
5. **Isolate Automation Safety Boundaries:** Explicitly bar automated LLM agents or GitHub Actions workflows from invoking live environment mutations (`terraform apply`, `kubectl delete`) without human validation.

## Consequences

- **Positive:** Guarantees a clear audit trail of structural network changes while protecting the stable release reference.
- **Positive:** Automates repository security setups, eliminating manual human UI adjustment errors.
- **Negative:** Adds branch synchronization overhead (dual PR paths for urgent hotfixes and releases) to the repository workflows.
- **Negative:** Mandates valid administrative API authentication tokens (`GH_TOKEN`) on the deploying machine during repo setup hooks.
