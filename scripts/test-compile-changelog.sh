#!/usr/bin/env bash
# Verifies milestone splitting, completed-milestone handling and story-ID collision safety of compile-changelog.sh
# inside a throwaway git repository.
set -euo pipefail

fail() { echo "[x] $1" >&2; exit 1; }
SCRIPT="$PWD/scripts/compile-changelog.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
git init -q -b develop
git config user.email t@t; git config user.name t
mkdir -p docs/milestones

mk() { # file title status story-lines...
    local f="$1" t="$2" s="$3"; shift 3
    { echo "# $t"; echo; echo "- **Status:** $s"; echo; echo "### Epic 1: X"; echo; printf '%s\n' "$@"; } > "$f"
}
mk docs/milestones/01-a.md "Milestone 01: Alpha" "Approved / Target for Execution" \
    "- **Story 1.1**: Alpha one." "- **Story 1.2**: Alpha two."
mk docs/milestones/02-b.md "Milestone 02: Beta" "Approved / Target for Execution" \
    "- **Story 1.1:** Beta one." "- **Story 1.2:** Beta two."
echo "# template" > docs/milestones/template-kanban-board.md
git add -A; git commit -qm "chore: seed"
git commit -q --allow-empty -m "feat: alpha one (Story 1.1)"
git commit -q --allow-empty -m "infra: complete Milestone 01 (Story 1.2)"

bash "$SCRIPT" >/dev/null || fail "run 1 failed"
grep -q "Active Focus Boundary:\*\* Milestone 02: Beta" KANBAN.md || fail "active milestone is not 02"
grep -q "<summary>🏁 Milestone 01: Alpha — Completed" KANBAN.md || fail "milestone 01 not collapsed as completed"
grep -q "^## 🎯 Milestone 02: Beta — Active" KANBAN.md || fail "milestone 02 section missing"
grep -q "template" KANBAN.md && fail "template file leaked into the board"
awk '/Milestone 02: Beta — Active/{f=1} f' KANBAN.md | grep -q "^| | | .*Story 1.1" && fail "Story 1.1 collided across milestones"
grep -q "Completed Milestone: Milestone 01: Alpha" CHANGELOG.md || fail "changelog lacks milestone 01 section"

# Tagged commit attributes Story 1.1 to Milestone 02 only.
git commit -q --allow-empty -m "infra: beta network (M02 Epic 1 / Story 1.1)"
bash "$SCRIPT" >/dev/null || fail "run 2 failed"
awk '/Milestone 02: Beta — Active/{f=1} f' KANBAN.md | grep -q "^| | | .*Story 1.1" || fail "tagged Story 1.1 not delivered in 02"
awk '/Milestone 02: Beta — Active/{f=1} f' KANBAN.md | grep -q "^| .*Story 1.2.* | | |$" || fail "Story 1.2 of 02 must stay in backlog"
grep -q "Active Tracking Context: Milestone 02: Beta" CHANGELOG.md || fail "changelog lacks milestone 02 section"

# Idempotency: reruns replace, never stack, [Unreleased].
bash "$SCRIPT" >/dev/null
[ "$(grep -c '^## \[Unreleased\]' CHANGELOG.md)" = "1" ] || fail "[Unreleased] stacked"
echo "[✓] milestone split, completed-milestone handling and collision safety passed"
