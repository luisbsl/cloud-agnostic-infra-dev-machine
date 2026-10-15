#!/usr/bin/env bash
# Verifies the protected-branch hooks in a throwaway repository: blocks commits and merge commits on
# develop/main, allows topic branches, detached HEAD and the explicit bypass, and the installer is idempotent.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
SRC="$PWD"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init -q -b develop
git config user.email t@t; git config user.name t
mkdir -p .githooks scripts
cp "$SRC"/.githooks/* .githooks/
cp "$SRC"/scripts/install-git-hooks.sh scripts/
bash scripts/install-git-hooks.sh >/dev/null
bash scripts/install-git-hooks.sh >/dev/null || fail "installer not idempotent"
[ "$(git config core.hooksPath)" = ".githooks" ] || fail "hooksPath not set"
for h in .githooks/pre-commit .githooks/pre-merge-commit .githooks/_guard.sh; do [ -x "$h" ] || fail "$h not executable"; done

echo a > a; git add a
OUT="$(git commit -m "direct" 2>&1)" && fail "commit on develop was allowed"
echo "$OUT" | grep -q "Direct commits to 'develop' are blocked" || fail "missing descriptive error on develop"
[ -z "$(git rev-parse -q --verify HEAD || true)" ] || fail "commit landed on develop despite the block"

ALLOW_PROTECTED_BRANCH_COMMIT=1 git commit -qm "bootstrap" || fail "explicit bypass rejected"

git switch -q -c infra/topic
echo b > b; git add b; git commit -qm "topic work" || fail "topic branch commit blocked"
echo "[✓] develop commit blocked, bypass and topic branch commit allowed"

git switch -q develop
git switch -q -c feature/other; echo c > c; git add c; git commit -qm "other"; git switch -q develop
OUT="$(git merge --no-ff -m "merge" infra/topic 2>&1)" && fail "merge commit on develop was allowed"
echo "$OUT" | grep -q "are blocked" || fail "merge block message missing"
git merge --abort 2>/dev/null || true
git merge -q --ff-only infra/topic || fail "fast-forward on develop must remain allowed"
echo "[✓] merge commit blocked, fast-forward allowed"

git branch -q -m develop main
echo d > d; git add d
OUT="$(git commit -qm "direct" 2>&1)" && fail "commit on main was allowed"
echo "$OUT" | grep -q "Direct commits to 'main' are blocked" || fail "main not protected"

git switch -q --detach HEAD
git commit -q --allow-empty -m "detached" || fail "detached HEAD commit blocked"
echo "[✓] main protected, detached HEAD allowed — protected-branch hooks passed"
