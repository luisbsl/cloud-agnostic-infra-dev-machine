#!/usr/bin/env bash
# Activates the versioned Git hooks in .githooks/ for this clone (idempotent).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/* scripts/install-git-hooks.sh
git config core.hooksPath .githooks
echo "[✓] core.hooksPath=$(git config core.hooksPath); commits on main/develop are now blocked."
