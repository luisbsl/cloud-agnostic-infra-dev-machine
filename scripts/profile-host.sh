#!/usr/bin/env bash

set -euo pipefail

INFO="[•]"
SUCCESS="[✓]"
WARNING="[!]"

echo "================================================================="
echo "  LOCAL HOST HARDWARE PROFILER FOR CONTAINER PLATFORM SIZING    "
echo "================================================================="

OS_TYPE="$(uname -s)"
echo "$INFO Detecting Host OS... $OS_TYPE"

if [ "$OS_TYPE" = "Darwin" ]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
    TOTAL_RAM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_RAM_GB=$(( TOTAL_RAM_BYTES / 1024 / 1024 / 1024 ))
    DISK_AVAILABLE_GB=$(df -g / | awk 'NR==2 {print $4}')
elif [ "$OS_TYPE" = "Linux" ]; then
    CPU_CORES=$(nproc)
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))
    DISK_AVAILABLE_GB=$(df -k / | awk 'NR==2 {print int($4/1024/1024)}')
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

# Preserve minimum host overhead (2 Cores, 4GB RAM, 40GB Disk)
SAFE_CPU=$(( CPU_CORES - 2 ))
SAFE_RAM=$(( TOTAL_RAM_GB - 4 ))
SAFE_DISK=$(( DISK_AVAILABLE_GB - 40 ))

if [ $SAFE_CPU -lt 2 ] || [ $SAFE_RAM -lt 4 ]; then
    echo "$WARNING Host resources are tight. Ansible pre-flight assertions may clamp allocations."
fi

# Calculate Container Sizing Profile
if [ "$SAFE_RAM" -ge 16 ]; then
    TIER1_CPU=6
    TIER1_RAM=12
    TIER23_CPU=1
    TIER23_RAM=2
    KUMA_CPU=1
    KUMA_RAM=2
elif [ "$SAFE_RAM" -ge 8 ]; then
    TIER1_CPU=4
    TIER1_RAM=8
    TIER23_CPU=1
    TIER23_RAM=1
    KUMA_CPU=1
    KUMA_RAM=1
else
    TIER1_CPU=2
    TIER1_RAM=4
    TIER23_CPU=1
    TIER23_RAM=1
    KUMA_CPU=1
    KUMA_RAM=1
fi

TOTAL_REQ_CPU=$(( TIER1_CPU + TIER23_CPU + KUMA_CPU ))
TOTAL_REQ_RAM=$(( TIER1_RAM + TIER23_RAM + KUMA_RAM ))

cat <<EOF
[Container Platform Resource Allocation Matrix]
* Computing Fabric (Tier 1 ECCS)      : ${TIER1_CPU} Cores, ${TIER1_RAM} GB RAM
* Ingress Gateway (Tier 2 & 3 CALBS)  : ${TIER23_CPU} Core, ${TIER23_RAM} GB RAM
* Kuma SDN Control Plane             : ${KUMA_CPU} Core, ${KUMA_RAM} GB RAM

[Aggregate Ecosystem Clamping Limit]
* Total Allocated CPU  : $TOTAL_REQ_CPU Cores (Host Threads: $CPU_CORES)
* Total Allocated RAM  : $TOTAL_REQ_RAM GB (Host Memory: $TOTAL_RAM_GB GB)
=================================================================
EOF