#!/usr/bin/env bash

set -euo pipefail

# Visual Anchors for Terminal output
INFO="[•]"
SUCCESS="[✓]"
WARNING="[!]"

echo "================================================================="
echo "  LOCAL HOST HARDWARE PROFILER FOR VM CAPACITY PLANNING          "
echo "================================================================="

# 1. Detect Host Operating System
OS_TYPE="$(uname -s)"
echo "$INFO Detecting Host OS... $OS_TYPE"

# 2. Gather CPU Threads, Total RAM, and Available Storage based on OS
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS Runtime Parsing
    CPU_CORES=$(sysctl -n hw.ncpu)
    TOTAL_RAM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_RAM_GB=$(( TOTAL_RAM_BYTES / 1024 / 1024 / 1024 ))
    # Available Disk Space in GB on the primary root partition
    DISK_AVAILABLE_GB=$(df -g / | awk 'NR==2 {print $4}')
elif [ "$OS_TYPE" = "Linux" ]; then
    # Linux Runtime Parsing
    CPU_CORES=$(nproc)
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))
    DISK_AVAILABLE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
else
    echo "$WARNING Unsupported Host Operating System: $OS_TYPE"
    exit 1
fi

echo "$SUCCESS Host Hardware Profiling Complete!"
echo "-----------------------------------------------------------------"
echo "  Host CPU Threads available : $CPU_CORES Cores"
echo "  Host System Memory         : $TOTAL_RAM_GB GB"
echo "  Host Storage Available     : $DISK_AVAILABLE_GB GB"
echo "-----------------------------------------------------------------"

# 3. Dynamic Threshold Math & Allocation Boundaries
# We preserve 2 Cores and 4GB RAM safely for your native Host UI/daemons
SAFE_CPU=$(( CPU_CORES - 2 ))
SAFE_RAM=$(( TOTAL_RAM_GB - 4 ))
SAFE_DISK=$(( DISK_AVAILABLE_GB - 40 )) # Protect 40GB host overhead

if [ $SAFE_CPU -lt 2 ] || [ $SAFE_RAM -lt 4 ]; then
    echo "$WARNING Host resources are extremely tight for a 4-node VM cluster."
    echo "          Proceed with micro-allocations (1 vCPU, 1GB RAM per VM)."
fi

# 4. Generate Target 4-Node Cloud Architecture Sizing Plan
echo "  PROPOSED VM LAYER RESOURCE ALLOCATION (4 NODES TOTAL)"
echo "-----------------------------------------------------------------"

# Compute allocation footprints per node based on host availability
if [ "$SAFE_RAM" -ge 16 ]; then
    # Comfortable / Medium Development Footprint
    VM_CPU=2
    VM_RAM=4
    VM_DISK=25
elif [ "$SAFE_RAM" -ge 8 ]; then
    # Minimalist Footprint
    VM_CPU=1
    VM_RAM=2
    VM_DISK=20
else
    # Micro/Constrained Footprint
    VM_CPU=1
    VM_RAM=1
    VM_DISK=15
fi

TOTAL_REQ_CPU=$(( VM_CPU * 4 ))
TOTAL_REQ_RAM=$(( VM_RAM * 4 ))
TOTAL_REQ_DISK=$(( VM_DISK * 4 ))

# Output the calculated matrix
cat <<EOF
[Node Specification Matrix]
* 1x Control Plane VM : ${VM_CPU} vCPU, ${VM_RAM} GB RAM, ${VM_DISK} GB Disk
* 2x Worker Nodes     : ${VM_CPU} vCPU, ${VM_RAM} GB RAM, ${VM_DISK} GB Disk (Each)
* 1x Utility Node     : 1 vCPU, 1 GB RAM, 15 GB Disk

[Total Overhead Across Virtualization Layer]
* Total Reserved CPU  : $TOTAL_REQ_CPU Cores (Host Capacity: $CPU_CORES)
* Total Reserved RAM  : $TOTAL_REQ_RAM GB (Host Capacity: $TOTAL_RAM_GB GB)
* Total Reserved Disk : $TOTAL_REQ_DISK GB (Host Capacity: $DISK_AVAILABLE_GB GB)
=================================================================
EOF
