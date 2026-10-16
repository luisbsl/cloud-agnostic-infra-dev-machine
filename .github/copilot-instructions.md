# GitHub Copilot Agent Mode - Repository Instructions & Governance

## 1. Context & Architectural Boundaries

- **Project Type**: Cloud-Agnostic Infrastructure & Platform Simulation as Code.
- **Resource Constraints**: Total ecosystem capped at 8 vCPUs / 16 GB RAM ceiling.
- **Token Efficiency Directive**: Keep all generated code, explanations, and specifications compact, concise, and direct. Avoid conversational filler or redundant prose. Reference repository docs (`docs/*`) by file path rather than dumping text into prompts.

## 2. Local CI Pre-Flight: Run the same gates as the validation pipeline before committing:

     - `bash scripts/sandbox-run.sh "bash scripts/run-ci-pipeline.sh --all"`
     - `git diff --check` (and `git diff --cached --check` after staging)

## 3. Version Control & Gitflow Mandate

- **Branch Target**: All development flows through short-lived topic branches (`feature/*`, `fix/*`, `infra/*`, `docs/*`) targeting `develop`. Never commit directly to `main` or `develop`.
- **Merge Policy**: Enforce explicit merge commits via GitHub CLI (`gh pr merge --merge --delete-branch`). Disallow squash/rebase merges on target branches per `docs/versioning/git-workflow.md`.
- **CI Verification**: Always monitor status checks via `gh pr checks` before merging.

## 4. End-of-Task Execution Output Directive

- At the end of every single smart GHERKIN task output, you MUST output a dedicated `git+gh` CLI execution section. The local CI pre-flight step must execute the unified matrix pipeline: `bash scripts/sandbox-run.sh "bash scripts/run-ci-pipeline.sh --all"`.
