# Git workflow

This guide defines the repository's lightweight Gitflow using Git, GitHub
Actions, and GitHub CLI (`gh`). It governs review and versioning of this
local-only infrastructure repository. It does not authorize CI or a release
to provision, update, or destroy infrastructure.

## Strategy

Use Gitflow's `main`/`develop` separation without requiring release branches
for routine changes. `main` contains reviewed, releasable repository
baselines; `develop` is the integration branch. Short-lived change branches
flow through pull requests. Create `release/*` only when preparing a deliberate
versioned baseline, and `hotfix/*` only for an urgent correction to a tagged
baseline.

Classic Gitflow usually gives every planned release a release branch and adds
more branch-management ceremony. That is unnecessary here because this
repository has no application deployment train. Trunk-based development would
be simpler, but would remove the explicit integration branch and release
isolation. The selected compromise keeps `main` and `develop`, and makes
release/hotfix branches conditional rather than routine.

This retains review history and a stable release reference while avoiding
application-style deployment stages that this repository does not have. A
small solo-maintained repository may find the permanent `develop` branch
unnecessary; if that overhead outweighs its release value, revisit this policy
and adopt a documented trunk-based workflow rather than letting the branches
drift.

## Initial adoption

Before using this workflow, connect the checkout to the actual GitHub
repository and confirm its default branch and current protections. This
workspace has no Git metadata, so these commands are instructions for the
maintainer to run only in the correct repository:

```bash
gh auth status
gh repo view OWNER/REPO --json nameWithOwner,defaultBranchRef
git fetch origin
```

If the existing default branch is `main`, create `develop` from its current
tip:

```bash
git switch main
git pull --ff-only origin main
git switch -c develop
git push --set-upstream origin develop
```

If the repository uses a different default branch, stop and agree on a
migration before renaming it or creating `develop`. After the initial branches
exist, configure their PR, merge-commit, required-check, review, and deletion
rules in GitHub settings. No branch or ruleset is created by this guide.

## Branches and destinations

| Branch | Purpose | Created from | Pull request target |
| --- | --- | --- | --- |
| `main` | Reviewed, releasable snapshots; version tags point here | Existing default branch during adoption | No direct change branches |
| `develop` | Integration of ordinary repository changes | `main` at adoption | No direct change branches |
| `feature/<topic>` | New platform capability or repository feature | `develop` | `develop` |
| `fix/<topic>` | Non-urgent correction | `develop` | `develop` |
| `docs/<topic>` | Documentation-only change | `develop` | `develop` |
| `infra/<topic>` | Terraform, K3s, or shared-platform configuration | `develop` | `develop` |
| `release/vX.Y.Z` | Optional preparation of a versioned repository baseline | `develop` | `main`, then `develop` |
| `hotfix/<topic>` | Urgent correction to a tagged baseline | `main` | `main`, then `develop` |

Use short, lowercase, hyphen-separated topic names. Delete a short-lived branch
after its pull request has merged to every required target.

## Pull request and merge policy

1. Do work on a short-lived branch; do not commit directly to `main` or
   `develop`.
2. Open a pull request to the target shown above. Describe scope, validation,
   infrastructure impact (if any), and rollback.
3. Require the repository's validation check to pass. Require an independent
   review when another maintainer is available. A solo maintainer must perform
   and record a deliberate self-review; self-approval is not an independent
   review.
4. Merge using a merge commit. Configure repository merge settings to allow
   merge commits and disallow squash/rebase merges for this workflow.
5. Do not force-push or delete `main` or `develop`. Protect both branches from
   direct pushes and deletion through GitHub rulesets or branch protection.
   Require pull requests and the validation check. Configure approval rules
   according to the available independent reviewers; do not make a review
   count impossible for a solo-maintained repository.

Rulesets and branch protection live in GitHub repository settings. This guide
does not create or change them. Confirm the actual default branch, collaborators,
and required-check name on GitHub before enabling protections.

## Ordinary change

Start from the current integration branch:

```bash
git switch develop
git pull --ff-only origin develop
git switch -c docs/update-runbook
```

After making and validating the change:

```bash
git add README.md docs/versioning/git-workflow.md .github/workflows/ci.yml
git diff --cached --check
git commit -m "docs: update contribution workflow"
git push --set-upstream origin docs/update-runbook
gh pr create --base develop --title "docs: update contribution workflow" --body "Describe the change, validation, and rollback."
```

Stage only files belonging to the change; the file list above is an example.
Review the pull request and its checks, then merge it with the configured merge
commit policy:

```bash
gh pr view --web
gh pr checks
gh pr merge --merge
```

Use `gh auth status` to check CLI authentication without displaying token
values. Authenticate interactively with `gh auth login` when needed; never put
credentials in shell commands, files, or workflow logs.

## Release and hotfix lifecycle

### Optional release

Use a release branch only when a named, reproducible repository baseline is
valuable. Release tags describe the reviewed repository content, not an applied
platform state and not a production deployment.

1. Create `release/vX.Y.Z` from up-to-date `develop`.
2. Make release-only documentation or configuration corrections on that
   branch. Open and merge a PR to `main`.
3. Open and merge a second PR from the same release branch to `develop` so
   release-only changes are not lost. Keep the branch until both PRs merge.
4. From the updated `main`, create and push an annotated tag, then publish the
   matching GitHub release if release notes are useful:

```bash
git switch main
git pull --ff-only origin main
git tag -a vX.Y.Z -m "Local platform baseline vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z --verify-tag --title "Local platform baseline vX.Y.Z" --generate-notes
```

Replace `vX.Y.Z` with a concrete version before running these commands.
Follow the repository's versioning convention once one is adopted; do not
create a release for every documentation or infrastructure PR.

### Urgent hotfix

Create `hotfix/<topic>` from up-to-date `main`. Open a PR to `main`, merge it,
then open a PR from the same hotfix branch to `develop` and merge it. Tag a
versioned correction only if the tagged baseline needs an updated reference.
Retain the hotfix branch until both PRs have merged, then delete it.

## GitHub Actions and safety boundary

The [Repository validation workflow](../../.github/workflows/ci.yml) runs on pull
requests targeting `main` or `develop`. It checks PR diff whitespace with
`git diff --check`. This is a small integrity check, not Terraform, Kubernetes,
or shell validation; the workspace currently contains no corresponding
implementation files or test tooling. Add relevant checks when those sources
and their supported validation commands exist.

The workflow has read-only repository contents permission, uses a
commit-pinned checkout action, and does not use secrets. Never add Terraform
apply/destroy, `kubectl` mutations, credential rotation, Vault initialization,
or other privileged infrastructure operations to CI. Infrastructure changes
still require a human-reviewed diff, applicable validation, and explicit
human approval before privileged operations.

Use `gh` to inspect CI; this workflow is pull-request-triggered and is not
manually dispatchable:

```bash
gh run list --branch docs/update-runbook --limit 5
gh run view RUN_ID --log-failed
```

Replace `RUN_ID` with the workflow run ID. For branch protection, select the
check produced by `Repository validation` after its first successful run.

## Recovery

- If checks fail, inspect the failed step with
  `gh run view RUN_ID --log-failed`, fix the branch, and push another commit.
  Do not bypass a required check.
- Before merge, close an incorrect PR or correct it with a new commit.
- After merge, use a reviewed revert PR rather than rewriting protected
  history. For a merge commit on the target branch, create a recovery branch
  and revert with its first parent as the mainline:

```bash
git switch main
git pull --ff-only origin main
git switch -c fix/revert-bad-change
git revert -m 1 MERGE_COMMIT
git push --set-upstream origin fix/revert-bad-change
gh pr create --base main --title "fix: revert bad change" --body "Explain the impact and recovery."
```

Replace `MERGE_COMMIT` with the merge commit ID. Use `develop` as the base
instead when reverting a change there. Do not delete or move a published tag
to conceal a bad release; publish a corrected version and explain the
superseded reference.

## References

- [Repository baseline ADR-0001](../adr/0001-adopt-local-developer-platform-baseline.md)
- [Gitflow contribution workflow ADR-0003](../adr/0003-adopt-lightweight-gitflow-contribution-workflow.md)
- [GitHub CLI manual](https://cli.github.com/manual/)
- [GitHub Actions security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GitHub repository rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [actions/checkout v4.2.2](https://github.com/actions/checkout/releases/tag/v4.2.2)
