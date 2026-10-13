#!/usr/bin/env bash
# Verifies host workstation satisfies minimal prerequisites (Docker, Git, Shell).
# All other toolchains route strictly through the containerized sandbox environment.
set -euo pipefail

ERROR="[x]"
SUCCESS="[✓]"

command -v docker >/dev/null 2>&1 || { echo "$ERROR docker engine is required on host workstation" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "$ERROR git is required on host workstation" >&2; exit 1; }
command -v bash >/dev/null 2>&1 || { echo "$ERROR bash shell is required on host workstation" >&2; exit 1; }

echo "$SUCCESS Host dependencies verified: docker, git, and bash are available."
echo "$SUCCESS Workstation is ready for decoupled container sandbox execution."
