# filepath: scripts/run-ci-pipeline.sh
#!/usr/bin/env bash
# =========================================================================
#  DECLARATIVE MATRIX PIPELINE CONTROLLER & PIPELINE ORCHESTRATOR
#  Mirrors GitHub Actions design paradigms with automated crash recovery.
# =========================================================================
set -euo pipefail

# Visual Logging Anchors & Color Grids
C_RESET="\033[0m"
C_BLUE="\033[1;34m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"

INFO="${C_BLUE}[•]${C_RESET}"
SUCCESS="${C_GREEN}[✓]${C_RESET}"
WARNING="${C_YELLOW}[!]${C_RESET}"
CRITICAL="${C_RED}[x]${C_RESET}"

STAGE_COUNT=0
TOTAL_FAILED=0

# Emergency Workspace Evacuation Hook (Scale-to-Zero Invariant Enforcement)
trigger_pipeline_teardown() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\n${CRITICAL} ${C_RED}Pipeline execution loop broken abnormally! Triggering emergency evacuation runbook...${C_RESET}"
        if [ -f "playbooks/teardown-platform.yml" ]; then
            ansible-playbook playbooks/teardown-platform.yml || echo -e "${WARNING} Teardown playbook execution skipped or failed."
        fi
    fi
    exit "$exit_code"
}
trap trigger_pipeline_teardown EXIT INT TERM

run_step() {
    local script_path="$1"
    local desc="$2"

    echo -e "  ${INFO} Running Step: ${desc} (${script_path})..."

    if [ ! -x "$script_path" ]; then
        chmod +x "$script_path"
    fi

    set +e
    bash "$script_path" > /tmp/step_output.log 2>&1
    local step_rc=$?
    set -e

    if [ "$step_rc" -eq 0 ]; then
        echo -e "  ${SUCCESS} ${C_GREEN}PASS:${C_RESET} ${desc}"
    else
        echo -e "  ${CRITICAL} ${C_RED}FAIL:${C_RESET} ${desc} (Exit Code: ${step_rc})"
        echo -e "${C_YELLOW}----------------------- FAILURE LOG STREAM -----------------------${C_RESET}"
        cat /tmp/step_output.log >&2
        echo -e "${C_YELLOW}------------------------------------------------------------------${C_RESET}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        exit "$step_rc"
    fi
}

print_header() {
    STAGE_COUNT=$((STAGE_COUNT + 1))
    echo -e "\n${C_BLUE}=================================================================${C_RESET}"
    echo -e "  ${C_BLUE}STAGE ${STAGE_COUNT}:${C_RESET} $1"
    echo -e "${C_BLUE}=================================================================${C_RESET}"
}

usage() {
    echo "Usage: $0 [--stage <lint|unit|integration> | --all]"
    exit 1
}

if [ $# -eq 0 ]; then usage; fi

RUN_LINT=false
RUN_UNIT=false
RUN_INTEGRATION=false

while [ $# -gt 0 ]; do
    case "$1" in
        --all)
            RUN_LINT=true
            RUN_UNIT=true
            RUN_INTEGRATION=true
            shift
            ;;
        --stage)
            case "$2" in
                lint) RUN_LINT=true ;;
                unit) RUN_UNIT=true ;;
                integration) RUN_INTEGRATION=true ;;
                *) usage ;;
            esac
            shift 2
            ;;
        *) usage ;;
    esac
done

# -------------------------------------------------------------------------
# STAGE 1: Static Code Linting & Schema Validations
# -------------------------------------------------------------------------
if [ "$RUN_LINT" = true ]; then
    print_header "Static Code Linting & Schema Validations"
    run_step "scripts/validate-blueprint.sh" "Assert Central JSON Service Blueprint Integrity"
    run_step "scripts/test-requirements.sh" "Verify Ansible Galaxy Declarative Dependency Collection"
    run_step "scripts/test-git-hooks.sh" "Validate Native Gitflow Push Barrier Guardrails"
fi

# -------------------------------------------------------------------------
# STAGE 2: Ephemeral Sandbox Unit Test Blocks
# -------------------------------------------------------------------------
if [ "$RUN_UNIT" = true ]; then
    print_header "Ephemeral Sandbox Task Unit Tests"
    run_step "scripts/test-sandbox-run.sh" "Assert Scale-to-Zero Container Proxy Loop Execution"
    run_step "scripts/test-network-bridge.sh" "Verify Idempotent Bridge Fabric MTU Calculation"
    run_step "scripts/test-kuma-cp-core.sh" "Verify Cgroup Clamping and Port-Binding Configurations"
    run_step "scripts/test-compile-changelog.sh" "Verify POSIX Log Parser Splitting & Alignment Logic"
fi

# -------------------------------------------------------------------------
# STAGE 3: Multi-Tier Active Mesh Integration Testing
# -------------------------------------------------------------------------
if [ "$RUN_INTEGRATION" = true ]; then
    print_header "Multi-Tier Live Mesh Integration Diagnostics"
    run_step "scripts/test-kuma-cp-health.sh" "Query Synchronous Backoff Readiness Rest Verification Gates"
    run_step "scripts/test-provision-tiers.sh" "Validate Blueprint Ingestion Loop Routines"
    run_step "scripts/test-orchestrate-platform.sh" "Execute Full Stack Idempotency & E2E Validation Assertions"
fi

# Final Aggregated Reporting Boundary
echo -e "\n${C_GREEN}=================================================================${C_RESET}"
echo -e "  ${SUCCESS} ${C_GREEN}MATRIX PIPELINE COMPLETION SUMMARY${C_RESET}"
echo -e "  Total Job Failures Blocked: ${TOTAL_FAILED}"
echo -e "${C_GREEN}=================================================================${C_RESET}"
