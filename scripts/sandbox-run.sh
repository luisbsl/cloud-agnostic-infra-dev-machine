#!/usr/bin/env bash
# Synchronous sandbox driver executing platform tasks with strict scale-to-zero behavior.
set -euo pipefail

IMAGE_NAME="cloud-agnostic-dev-sandbox:latest"

# Build local dev-sandbox container image if not present
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "[•] Initializing localized sandbox container environment build..."
    docker build -t "$IMAGE_NAME" -f Dockerfile.dev-sandbox .
fi

# The sandbox shares the host network so localhost (e.g. the Kuma API on 127.0.0.1:5681) is the workstation's.

# If no specific arguments are provided, launch an interactive control plane terminal
if [ $# -eq 0 ]; then
    echo "[✓] Entering decoupled sandbox session. Scale-to-zero boundary active."
    exec docker run --rm -it --network host \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$PWD:/workspace" \
        -w /workspace \
        --entrypoint /bin/bash \
        "$IMAGE_NAME"
fi

# Execute explicit command and immediately scale down to zero upon task completion
exec docker run --rm --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PWD:/workspace" \
    -w /workspace \
    "$IMAGE_NAME" "$@"
