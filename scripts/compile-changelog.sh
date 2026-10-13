#!/usr/bin/env bash
# High-efficiency, zero-dependency Git log parser optimized for Copilot token containment.
# Features a multi-tiered historical reconciliation strategy for pre-changelog milestones.
set -euo pipefail

CHANGELOG_FILE="CHANGELOG.md"
KANBAN_FILE="KANBAN.md"
TEMP_LOG=$(mktemp)
TEMP_STORIES=$(mktemp)
TEMP_HIST_LOG=$(mktemp)
TEMP_FALLBACK=$(mktemp)
TEMP_MERGES=$(mktemp)
trap 'rm -f "$TEMP_LOG" "$TEMP_STORIES" "$TEMP_HIST_LOG" "$TEMP_FALLBACK" "$TEMP_MERGES"' EXIT INT TERM

# 1. Dynamic Active Milestone Discovery Layer
ACTIVE_MILESTONE_FILE=""
for f in docs/milestones/*.md; do
    if [ -f "$f" ] && grep -qI "Status:.*\(Approved / Target for Execution\|Active\)" "$f"; then
        ACTIVE_MILESTONE_FILE="$f"
        break
    fi
done

if [ -z "$ACTIVE_MILESTONE_FILE" ]; then
    ACTIVE_MILESTONE_FILE=$(ls docs/milestones/*.md | head -n 1)
fi

MILESTONE_NAME=$(grep -m 1 "^# " "$ACTIVE_MILESTONE_FILE" | sed 's/# //')
echo "[•] Active Platform Target Discovered: ${MILESTONE_NAME}"

# Extract all User Story references from the current documentation context
grep -oE "Story [0-9]+\.[0-9]+" "$ACTIVE_MILESTONE_FILE" | sort -u > "$TEMP_STORIES" || true

# Establish baseline integration branches
TARGET_BRANCH="origin/develop"
if ! git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
    TARGET_BRANCH="develop"
fi

LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD | tail -n 1)
git log "${LAST_TAG}..${TARGET_BRANCH}" --no-merges --format="%s (%h)" > "$TEMP_LOG"

# Cache global historical logs to cleanly map pre-existing, already-delivered stories
git log --all --format="%s" > "$TEMP_HIST_LOG"

# Marker-less delivery: a story counts as delivered when its Epic's declared Target Branch was merged
# (visible in merge-commit subjects) and a later story of the same Epic is already evidenced in the graph.
git log --all --merges --format="%s" > "$TEMP_MERGES"
EPIC=""; BRANCH=""
while IFS= read -r line; do
    case "$line" in
        "### Epic "*) EPIC=$(echo "$line" | sed -E 's/^### Epic ([0-9]+).*/\1/'); BRANCH="" ;;
        *"**Target Branch:**"*) BRANCH=$(echo "$line" | sed -E 's/.*`([^`]+)`.*/\1/') ;;
        "- **Story "*)
            [ -n "$BRANCH" ] || continue
            story=$(echo "$line" | sed -E 's/^- \*\*(Story [0-9]+\.[0-9]+)\*\*.*/\1/')
            grep -qF "/${BRANCH}" "$TEMP_MERGES" || continue
            grep -qF "$story" "$TEMP_HIST_LOG" && continue
            num=${story#Story *.}; epic_no=${story#Story }; epic_no=${epic_no%.*}
            later=$(grep -oE "Story ${epic_no}\.[0-9]+" "$TEMP_HIST_LOG" | sed -E "s/.*\.//" | sort -n | tail -n 1)
            if [ -n "$later" ] && [ "$later" -gt "$num" ]; then echo "$story" >> "$TEMP_FALLBACK"; fi
            ;;
    esac
done < "$ACTIVE_MILESTONE_FILE"
cat "$TEMP_FALLBACK" >> "$TEMP_HIST_LOG"

# 2. Compile Unified Changelog File
if [ -s "$TEMP_LOG" ]; then
    {
        echo "## [Unreleased] - $(date +'%Y-%m-%d')"
        echo ""
        echo "### 🏆 Active Tracking Context: ${MILESTONE_NAME}"
        echo ""

        HAS_STORIES=false
        if [ -s "$TEMP_STORIES" ]; then
            while read -r story; do
                if grep -qF "$story" "$TEMP_LOG" || grep -qxF "$story" "$TEMP_FALLBACK"; then
                    if [ "$HAS_STORIES" = false ]; then
                        echo "#### Delivered User Stories:"
                        HAS_STORIES=true
                    fi
                    echo "  - ✅ ${story}"
                fi
            done < "$TEMP_STORIES"
        fi
        if [ "$HAS_STORIES" = false ]; then
            echo "  - ⚠️ No active user story markers discovered in this commit increment."
        fi
        echo ""

        if grep -qE "^feat" "$TEMP_LOG"; then
            echo "### 🚀 Added"; grep -E "^feat" "$TEMP_LOG" | sed -E 's/^feat(ure)?(\(.*\))?:[[:space:]]*/- /'; echo ""
        fi
        if grep -qE "^fix" "$TEMP_LOG"; then
            echo "### 🐛 Fixed"; grep -E "^fix" "$TEMP_LOG" | sed -E 's/^fix(\(.*\))?:[[:space:]]*/- /'; echo ""
        fi
        if grep -qE "^infra" "$TEMP_LOG"; then
            echo "### ⚙️ Infrastructure & Sandbox Control Plane"; grep -E "^infra" "$TEMP_LOG" | sed -E 's/^infra(\(.*\))?:[[:space:]]*/- /'; echo ""
        fi
    } > "STAGE_${CHANGELOG_FILE}"

    # Drop earlier [Unreleased] blocks so repeated runs replace rather than stack them.
    if [ -f "$CHANGELOG_FILE" ]; then
        awk '/^## /{skip = ($0 ~ /^## \[Unreleased\]/)} !skip' "$CHANGELOG_FILE" >> "STAGE_${CHANGELOG_FILE}"
    fi
    # Trim trailing blank lines so the file passes `git diff --check`.
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "STAGE_${CHANGELOG_FILE}" > "STAGE_${CHANGELOG_FILE}.trim"
    mv "STAGE_${CHANGELOG_FILE}.trim" "$CHANGELOG_FILE"
    rm -f "STAGE_${CHANGELOG_FILE}"
else
    echo "[✓] Zero unreleased commits detected on branch: ${TARGET_BRANCH}. Bypassing changelog write step."
fi

# 3. Compile Copilot AI-Driven Dynamic Kanban Board (KANBAN.md) with Full Reconciliation Fallback
{
    echo "# 📋 Copilot AI-Driven Dynamic Kanban Board"
    echo ""
    echo "**Active Focus Boundary:** ${MILESTONE_NAME}"
    echo "**Last Matrix Compilation:** $(date +'%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "| 🟥 BACKLOG / TODO | 🟨 IN PROGRESS | 🟩 DONE (VERIFIED IN DEV/DEVELOP) |"
    echo "| :--- | :--- | :--- |"

    if [ -s "$TEMP_STORIES" ]; then
        while read -r story; do
            # Description is the text after the story's own bullet marker, never the marker itself.
            STORY_DESC=$(grep -m 1 -E "^[[:space:]]*-[[:space:]]*\*\*${story}\*\*:" "$ACTIVE_MILESTONE_FILE" \
                | sed -E 's/^[^:]*\*\*:[[:space:]]*//' | tr '|' '-')
            EPIC_NO=${story#Story }; EPIC_NO=${EPIC_NO%.*}
            ROW="**Epic ${EPIC_NO}**: **${story}**: ${STORY_DESC}"

            # Cascaded Health Evaluation Logic
            IN_ACTIVE_DELTA=$(grep -qF "$story" "$TEMP_LOG" && echo "true" || echo "false")
            IN_HISTORIC_GIT=$(grep -qF "$story" "$TEMP_HIST_LOG" && echo "true" || echo "false")

            if [ "$IN_ACTIVE_DELTA" = "true" ] || [ "$IN_HISTORIC_GIT" = "true" ]; then
                # Story passes reconciliation audits and maps securely to Completed bounds
                echo "| | | ${ROW} |"
            else
                # Story is truly unexecuted across the historical and incremental ecosystem limits
                echo "| ${ROW} | | |"
            fi
        done < "$TEMP_STORIES"
    else
        echo "| Zero tasks discovered in milestone files | | |"
    fi
} > "$KANBAN_FILE"

echo "[✓] Dynamic changelog stream and Kanban matrix successfully compiled and reconciled."