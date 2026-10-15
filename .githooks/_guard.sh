#!/usr/bin/env bash
# Shared guard: refuses to create commits directly on protected Gitflow branches.
# Detached HEAD (rebase, bisect) is allowed. Emergency bypass: ALLOW_PROTECTED_BRANCH_COMMIT=1.
set -euo pipefail

PROTECTED_BRANCHES="main develop"
branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"

for p in $PROTECTED_BRANCHES; do
    if [ "$branch" = "$p" ] && [ "${ALLOW_PROTECTED_BRANCH_COMMIT:-0}" != "1" ]; then
        {
            echo "[x] Direct commits to '$p' are blocked (docs/versioning/git-workflow.md)."
            echo "    Move your work to a topic branch, then open a PR targeting develop:"
            echo "      git switch -c <feature|fix|infra|docs>/<topic>"
            echo "    Emergency bypass (discouraged): ALLOW_PROTECTED_BRANCH_COMMIT=1 git commit ..."
        } >&2
        exit 1
    fi
done
