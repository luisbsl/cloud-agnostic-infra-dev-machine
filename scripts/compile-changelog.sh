#!/usr/bin/env bash
# Milestone-aware Git log parser: splits CHANGELOG.md and KANBAN.md per milestone in docs/milestones/*.md.
# Commits are attributed to a milestone by explicit tag ("Milestone 02" / "M02"), else chronologically:
# a "complete Milestone NN" commit closes NN, and later untagged work flows to the next open milestone.
set -euo pipefail

CHANGELOG_FILE="CHANGELOG.md"
KANBAN_FILE="KANBAN.md"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK" "STAGE_${CHANGELOG_FILE}" "STAGE_${CHANGELOG_FILE}.trim"' EXIT INT TERM

# Exact story-token match so "Story 1.1" never matches "Story 1.10".
has_story() { grep -qE "$(printf '%s' "$2" | sed 's/\./\\./')([^0-9]|\$)" "$1" 2>/dev/null; }

# 1. Milestone discovery (ordered by filename; template files without a numeric prefix are ignored)
MS_FILES=()
for f in docs/milestones/[0-9]*.md; do [ -f "$f" ] && MS_FILES+=("$f"); done
if [ "${#MS_FILES[@]}" -eq 0 ]; then
    echo "[x] No milestone definitions found in docs/milestones/" >&2
    exit 1
fi

MS_NUM=(); MS_NAME=(); MS_STATIC_DONE=()
for i in "${!MS_FILES[@]}"; do
    f="${MS_FILES[$i]}"
    num=$(basename "$f" | sed -E 's/^0*([0-9]+)-.*/\1/')
    MS_NUM[$i]="$num"
    MS_NAME[$i]=$(grep -m 1 "^# " "$f" | sed 's/^# //')
    if grep -qiE "^- \*\*Status:\*\*.*(Completed|Done|Delivered|Closed|Released)" "$f"; then
        MS_STATIC_DONE[$i]=1
    else
        MS_STATIC_DONE[$i]=0
    fi
    grep -E "^- \*\*Story [0-9]+\.[0-9]+" "$f" | grep -oE "Story [0-9]+\.[0-9]+" | sort -u > "$WORK/ms.$i.stories" || true
    : > "$WORK/ms.$i.hist"; : > "$WORK/ms.$i.log"; : > "$WORK/ms.$i.fallback"
done
COUNT=${#MS_FILES[@]}

# 2. Chronological commit attribution
TARGET_BRANCH="origin/develop"
git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1 || TARGET_BRANCH="develop"
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD | tail -n 1)
git log "${LAST_TAG}..${TARGET_BRANCH}" --no-merges --format="%h" > "$WORK/unreleased.hashes"
git log --all --merges --format="%s" > "$WORK/merges"

CLOSED=()
for i in "${!MS_FILES[@]}"; do CLOSED[$i]=0; done

while IFS=$'\t' read -r hash subject; do
    [ -n "$hash" ] || continue
    target=-1
    # Explicit milestone tag wins.
    for i in "${!MS_FILES[@]}"; do
        if printf '%s' "$subject" | grep -qE "(Milestone ?0*${MS_NUM[$i]}|\bM0*${MS_NUM[$i]})([^0-9]|\$)"; then target=$i; break; fi
    done
    if [ "$target" -lt 0 ]; then
        story=$(printf '%s' "$subject" | grep -oE "Story [0-9]+\.[0-9]+" | head -n 1 || true)
        if [ -n "$story" ]; then
            for i in "${!MS_FILES[@]}"; do
                if [ "${CLOSED[$i]}" -eq 0 ] && has_story "$WORK/ms.$i.stories" "$story"; then target=$i; break; fi
            done
        fi
    fi
    if [ "$target" -lt 0 ]; then
        for i in "${!MS_FILES[@]}"; do
            if [ "${CLOSED[$i]}" -eq 0 ] && [ "${MS_STATIC_DONE[$i]}" -eq 0 ]; then target=$i; break; fi
        done
    fi
    [ "$target" -ge 0 ] || target=$((COUNT - 1))

    echo "$subject ($hash)" >> "$WORK/ms.$target.hist"
    if grep -qxF "$hash" "$WORK/unreleased.hashes"; then echo "$subject ($hash)" >> "$WORK/ms.$target.log"; fi

    # Completion marker closes the milestone for all later untagged work.
    if printf '%s' "$subject" | grep -qiE "complete[d]? +Milestone ?0*${MS_NUM[$target]}([^0-9]|\$)"; then
        CLOSED[$target]=1
    fi
done < <(git log --all --reverse --no-merges --format="%h%x09%s")

# 3. Marker-less delivery per milestone: an Epic's Target Branch was merged and a later story of that Epic is evidenced.
for i in "${!MS_FILES[@]}"; do
    EPIC=""; BRANCH=""
    while IFS= read -r line; do
        case "$line" in
            "### Epic "*) BRANCH="" ;;
            *"**Target Branch:**"*) BRANCH=$(echo "$line" | sed -E 's/.*`([^`]+)`.*/\1/') ;;
            "- **Story "*)
                [ -n "$BRANCH" ] || continue
                story=$(echo "$line" | grep -oE "Story [0-9]+\.[0-9]+" | head -n 1)
                grep -qF "/${BRANCH}" "$WORK/merges" || continue
                has_story "$WORK/ms.$i.hist" "$story" && continue
                num=${story##*.}; epic_no=${story#Story }; epic_no=${epic_no%.*}
                later=$(grep -oE "Story ${epic_no}\.[0-9]+" "$WORK/ms.$i.hist" | sed -E "s/.*\.//" | sort -n | tail -n 1 || true)
                if [ -n "$later" ] && [ "$later" -gt "$num" ]; then echo "$story" >> "$WORK/ms.$i.fallback"; fi
                ;;
        esac
    done < "${MS_FILES[$i]}"
    cat "$WORK/ms.$i.fallback" >> "$WORK/ms.$i.hist"
done

# 4. Per-milestone state: delivered stories and completion
MS_DONE=(); MS_STATE=()
for i in "${!MS_FILES[@]}"; do
    total=0; delivered=0
    while read -r story; do
        [ -n "$story" ] || continue
        total=$((total + 1))
        if has_story "$WORK/ms.$i.hist" "$story"; then delivered=$((delivered + 1)); echo "$story" >> "$WORK/ms.$i.delivered"; fi
    done < "$WORK/ms.$i.stories"
    touch "$WORK/ms.$i.delivered"
    if [ "${MS_STATIC_DONE[$i]}" -eq 1 ] || [ "${CLOSED[$i]}" -eq 1 ] || { [ "$total" -gt 0 ] && [ "$delivered" -eq "$total" ]; }; then
        MS_DONE[$i]=1
    else
        MS_DONE[$i]=0
    fi
done

ACTIVE=-1
for i in "${!MS_FILES[@]}"; do
    if [ "${MS_DONE[$i]}" -eq 0 ]; then ACTIVE=$i; break; fi
done
[ "$ACTIVE" -ge 0 ] || ACTIVE=$((COUNT - 1))
for i in "${!MS_FILES[@]}"; do
    if [ "${MS_DONE[$i]}" -eq 1 ]; then MS_STATE[$i]="Completed"
    elif [ "$i" -eq "$ACTIVE" ]; then MS_STATE[$i]="Active"
    else MS_STATE[$i]="Planned"; fi
    echo "[•] Milestone ${MS_NUM[$i]} (${MS_STATE[$i]}): ${MS_NAME[$i]}"
done
echo "[•] Active Platform Target Discovered: ${MS_NAME[$ACTIVE]}"

# 5. Compile changelog: one [Unreleased] section split per milestone (newest first)
HAS_UNRELEASED=false
for i in "${!MS_FILES[@]}"; do
    if [ -s "$WORK/ms.$i.log" ]; then HAS_UNRELEASED=true; fi
done

if [ "$HAS_UNRELEASED" = true ]; then
    {
        echo "## [Unreleased] - $(date +'%Y-%m-%d')"
        echo ""
        for ((i = COUNT - 1; i >= 0; i--)); do
            LOG="$WORK/ms.$i.log"
            [ -s "$LOG" ] || continue
            if [ "${MS_STATE[$i]}" = "Completed" ]; then
                echo "### 🏁 Completed Milestone: ${MS_NAME[$i]}"
            else
                echo "### 🏆 Active Tracking Context: ${MS_NAME[$i]}"
            fi
            echo ""
            HAS_STORIES=false
            while read -r story; do
                [ -n "$story" ] || continue
                if has_story "$LOG" "$story" || grep -qxF "$story" "$WORK/ms.$i.fallback"; then
                    if [ "$HAS_STORIES" = false ]; then echo "#### Delivered User Stories:"; HAS_STORIES=true; fi
                    echo "  - ✅ ${story}"
                fi
            done < "$WORK/ms.$i.stories"
            if [ "$HAS_STORIES" = false ]; then
                echo "  - ⚠️ No active user story markers discovered in this commit increment."
            fi
            echo ""
            if grep -qE "^feat" "$LOG"; then
                echo "#### 🚀 Added"; grep -E "^feat" "$LOG" | sed -E 's/^feat(ure)?(\(.*\))?:[[:space:]]*/- /'; echo ""
            fi
            if grep -qE "^fix" "$LOG"; then
                echo "#### 🐛 Fixed"; grep -E "^fix" "$LOG" | sed -E 's/^fix(\(.*\))?:[[:space:]]*/- /'; echo ""
            fi
            if grep -qE "^infra" "$LOG"; then
                echo "#### ⚙️ Infrastructure & Sandbox Control Plane"; grep -E "^infra" "$LOG" | sed -E 's/^infra(\(.*\))?:[[:space:]]*/- /'; echo ""
            fi
        done
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

# 6. Compile Kanban: one board per milestone; completed milestones are collapsed.
{
    echo "# 📋 Copilot AI-Driven Dynamic Kanban Board"
    echo ""
    echo "**Active Focus Boundary:** ${MS_NAME[$ACTIVE]}"
    echo "**Last Matrix Compilation:** $(date +'%Y-%m-%d %H:%M:%S')"
    echo ""
    for i in "${!MS_FILES[@]}"; do
        if [ "${MS_STATE[$i]}" = "Completed" ]; then
            echo "<details><summary>🏁 ${MS_NAME[$i]} — Completed</summary>"
            echo ""
        else
            ICON="🗓️"
            if [ "${MS_STATE[$i]}" = "Active" ]; then ICON="🎯"; fi
            echo "## ${ICON} ${MS_NAME[$i]} — ${MS_STATE[$i]}"
            echo ""
        fi
        echo "| 🟥 BACKLOG / TODO | 🟨 IN PROGRESS | 🟩 DONE (VERIFIED IN DEV/DEVELOP) |"
        echo "| :--- | :--- | :--- |"
        if [ -s "$WORK/ms.$i.stories" ]; then
            while read -r story; do
                STORY_DESC=$(grep -m 1 -E "^[[:space:]]*-[[:space:]]*\*\*${story}:?\*\*" "${MS_FILES[$i]}" \
                    | sed -E 's/^[^*]*\*\*Story [0-9]+\.[0-9]+:?\*\*:?[[:space:]]*//' | tr '|' '-')
                EPIC_NO=${story#Story }; EPIC_NO=${EPIC_NO%.*}
                ROW="**Epic ${EPIC_NO}**: **${story}**: ${STORY_DESC}"
                if grep -qxF "$story" "$WORK/ms.$i.delivered"; then
                    echo "| | | ${ROW} |"
                else
                    echo "| ${ROW} | | |"
                fi
            done < "$WORK/ms.$i.stories"
        else
            echo "| Zero tasks discovered in milestone files | | |"
        fi
        echo ""
        if [ "${MS_STATE[$i]}" = "Completed" ]; then echo "</details>"; echo ""; fi
    done
} | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$KANBAN_FILE"

echo "[✓] Dynamic changelog stream and Kanban matrix successfully compiled and reconciled."
