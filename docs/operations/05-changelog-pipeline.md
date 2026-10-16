# Operational Excellence: Milestone-Aware Changelog & Dynamic Kanban Board Pipeline

This document defines the architecture, data structures, and automation runbooks governing the zero-dependency repository log streaming pipeline.

## 1. Architectural Strategy & Token Optimization

To optimize context token space and avoid package inflation (e.g., Node/npm or Rust binaries), the workspace leverages a **POSIX-Native Git Stream Processor** (`scripts/compile-changelog.sh`).

The pipeline runs synchronously inside the decoupled sandbox container environment, scanning metadata logs and converting Conventional Commits into structured documentation items on-the-fly.

```mermaid
graph TD
    subgraph ExecutionBounds ["Sandbox Runtime Environment"]
        A[scripts/compile-changelog.sh] -->|1. Scans Metadata status: Active| B(docs/milestones/*.md)
        B -->|2. Extracts valid User Stories| C{Cascaded Reconciliation Layer}
    end

    subgraph GitGraph ["Repository History"]
        D[Incremental Delta Buffer] -->|Layer 1 Check| C
        E[Global Historical Git Tree] -->|Layer 2 Check| C
    end

    C -->|3. Compile Log| F[CHANGELOG.md]
    C -->|4. Update Status Matrix| G[KANBAN.md]
```

## 2. Multi-Tiered Historical Reconciliation Logic

To ensure that User Stories delivered prior to initializing this framework (e.g., Stories 1.1, 1.2, 2.1, 2.2) do not float backwards into the backlog column, the compiler script evaluates code states using four distinct cascading levels:

1. **Layer 1 (Unreleased Stream):** Evaluates the active incremental delta buffer (`LAST_TAG..TARGET_BRANCH`). If an item is found, it is logged under the active milestone context.
2. **Layer 2 (Historic Git Graph):** Searches the entire repository log graph (`git log --all`). If the user story token is matched in a past commit string, it resolves to completed.
3. **Layer 3 (Permanent Storage Logs):** Inspects the compiled `CHANGELOG.md` file artifact directly to handle historical squash merges safely.
4. **Layer 4 (Fallback Exclusion):** If no matching token exists across any layer, the task defaults to the `🟥 BACKLOG / TODO` row.

## 2.1 Per-Milestone Splitting & Completed Milestones

`compile-changelog.sh` processes **every** `docs/milestones/NN-*.md` file (unnumbered templates are ignored); stories are scoped per milestone, so identical IDs (e.g. `Story 1.1`) never collide.

- **Attribution:** a commit subject tagged `Milestone 02` or `M02` belongs to that milestone. Untagged commits flow chronologically: a `complete Milestone NN` commit closes NN, and later untagged work goes to the next open milestone. Tag post-completion fixes of an older milestone explicitly (e.g. `fix: ... (M01)`).
- **Completed milestones:** a milestone is `Completed` when its `Status:` says Completed/Done/Delivered/Closed/Released, a completion commit exists, or all its stories are delivered. The first non-completed milestone is `Active`; the rest are `Planned`.
- **Outputs:** `CHANGELOG.md` gets one `[Unreleased]` section per milestone (completed ones marked `🏁`); `KANBAN.md` gets one board per milestone, with completed boards collapsed in `<details>`. `Active Focus Boundary` always names the active milestone.
- **Verification:** `bash scripts/test-compile-changelog.sh` (also run in CI).

## 3. Automated Kanban Grid Synthesis

The compiler automatically outputs `KANBAN.md` using clean, compact markdown grid blocks. Tasks are organized under three explicit columns based on resolved state machine mappings:

- **🟥 BACKLOG / TODO:** Unexecuted or planned user stories.
- **🟨 IN PROGRESS:** Actively tracked development branch elements.
- **🟩 DONE (VERIFIED IN DEV/DEVELOP):** Completed, integrated, and verified milestone artifacts.

## 4. Operational Runbook

Invoke the pipeline compiler from the repository root inside the sandbox wrapper:

```bash
# Compile delta changelogs and synthesize the dynamic Kanban matrix
bash scripts/compile-changelog.sh

# Verify output consistency via pre-flight checks
test -f KANBAN.md && grep -q "Active Focus Boundary" KANBAN.md
```
