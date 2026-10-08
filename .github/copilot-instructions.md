# GitHub Copilot Agent Mode - Repository Instructions & Governance

## 1. Context & Architectural Boundaries

- **Project Type**: Cloud-Agnostic Infrastructure & Platform Simulation as Code.
- **Resource Constraints**: Total ecosystem capped at 8 vCPUs / 16 GB RAM ceiling.
- **Token Efficiency Directive**: Keep all generated code, explanations, and specifications compact, concise, and direct. Avoid conversational filler or redundant prose. Reference repository docs (`docs/*`) by file path rather than dumping text into prompts.

## 2. Shell & Scripting Standards

- **POSIX Shell Mandate**: Scripts must use `#!/bin/sh` or `#!/usr/bin/env bash` with strict error handling (`set -eu`). Avoid bashisms when writing POSIX scripts.
- **Idempotence & Teardown**: Always handle dynamic folder creation (`mkdir -p`) and atomic staging/cleanup (`trap` on `EXIT INT TERM`).

## 3. Version Control & Gitflow Mandate

- **Branch Target**: All development flows through short-lived topic branches (`feature/*`, `fix/*`, `infra/*`, `docs/*`) targeting `develop`. Never commit directly to `main` or `develop`.
- **Merge Policy**: Enforce explicit merge commits via GitHub CLI (`gh pr merge --merge --delete-branch`). Disallow squash/rebase merges on target branches per `docs/versioning/git-workflow.md`.
- **CI Verification**: Always monitor status checks via `gh pr checks` before merging.

## 4. End-of-Task Execution Output Directive

- At the end of **every single smart GHERKIN task/story output**, you MUST output a dedicated `git+gh` CLI execution section containing exact, executable commands for the stages below, in order. Commands must mirror the CI workflow (`.github/workflows/ci.yml`) so that local results predict remote results.
  1. **BRANCH CREATION**: Checkout `develop`, pull `--ff-only`, and branch creation (`git switch -c <type>/<topic>`).
  2. **LOCAL CI PRE-FLIGHT**: Run the same gates as the `Repository validation` workflow before committing, and do not proceed if any fails:
     - `jq empty docs/compiled-manifests/governance/protect-gitflow.json`
     - `bash scripts/validate-blueprint.sh blueprints/platform-services.json`
     - `sh scripts/render-manifests.sh` followed by `sh scripts/test-render-manifests.sh`
     - `git diff --check` (and `git diff --cached --check` after staging)
     Whenever a story adds or changes a CI-relevant artifact, the story MUST also add or update the matching `ci.yml` step so the pipeline enforces it.
  3. **STAGING AND COMMIT**: Staging (`git add`), whitespace checks (`git diff --cached --check`), and conventional commit message (`git commit -m "..."`). Never stage transient output under `docs/compiled-manifests/dataplanes/`.
  4. **PULL REQUEST & CI GATE**: Push branch, open PR via `gh pr create --base develop`, then block on CI with `gh pr checks --watch --fail-fast`. On failure, inspect with `gh run list --branch <branch> --limit 1` and `gh run view <run-id> --log-failed`, fix on the same branch, push, and re-watch. Never merge with failing or pending checks.
  5. **MERGE & SYNC**: Only after all checks pass, merge via `gh pr merge --merge --delete-branch`, then sync local `develop` (`git switch develop && git pull --ff-only`).
