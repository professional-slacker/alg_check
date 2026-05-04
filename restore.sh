#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   ALG Surface Restore Tool (undo solution.sh)       ${NC}"
echo -e "${YELLOW}====================================================${NC}"

# 1. Privilege Check
if [ $(id -u) -ne 0 ]; then
    echo -e "${RED}[Error] Root privileges required to reload kernel modules.${NC}"
    exit 1
fi

# 2. Reload AF_ALG kernel modules (undo of Step 1 in solution.sh)
echo -e "\n[Step 1: Reloading AF_ALG kernel modules]"
modules=("af_alg" "algif_rng" "algif_aead" "algif_skcipher" "algif_hash")

# Check if the module files exist on disk before attempting to load
K_PATH="/lib/modules/$(uname -r)/kernel/crypto/af_alg.ko.xz"
if [ ! -f "$K_PATH" ]; then
    echo -e "${YELLOW}WARNING: af_alg.ko.xz not found at $K_PATH${NC}"
    echo -e "${YELLOW}If you renamed/removed it, restore it first, then re-run this script.${NC}"
    echo -e "${YELLOW}Example: sudo mv ${K_PATH%.xz}.bak $K_PATH 2>/dev/null${NC}"
fi

for mod in "${modules[@]}"; do
    if lsmod | grep -q "^$mod"; then
        echo -e "INFO: $mod is already loaded."
    else
        modprobe "$mod" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SUCCESS: $mod has been reloaded.${NC}"
        else
            echo -e "${RED}FAILURE: Could not reload $mod. Module file may be missing.${NC}"
        fi
    fi
done

# 3. Final verification
echo -e "\n[Step 2: Verifying AF_ALG socket is functional again]"
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${YELLOW}UNVERIFIED: python3 is not installed. Cannot test AF_ALG socket.${NC}"
    echo -e "${YELLOW}RESULT: Install python3 or verify manually.${NC}"
else
    RESULT=$(python3 -c "
import sys
try:
    import socket
except ImportError:
    sys.exit(2)
try:
    s = socket.socket(38, 5, 0)
    s.close()
    sys.exit(0)
except OSError:
    sys.exit(1)
" 2>&1)
    RC=$?
    if [ $RC -eq 0 ]; then
        echo -e "${GREEN}VERIFIED: AF_ALG socket creation succeeded.${NC}"
        echo -e "${GREEN}RESULT: System has been restored to pre-solution.sh state.${NC}"
    elif [ $RC -eq 1 ]; then
        echo -e "${RED}ALERT: AF_ALG socket still rejected.${NC}"
        echo -e "${RED}Check that all module files exist on disk and were loaded.${NC}"
    else
        echo -e "${YELLOW}UNVERIFIED: Python socket module unavailable.${NC}"
        echo -e "${YELLOW}DETAIL: $RESULT${NC}"
        echo -e "${YELLOW}RESULT: Cannot confirm AF_ALG restoration status.${NC}"
    fi
fi

echo -e "\n${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   Restore complete.                                  ${NC}"
echo -e "${YELLOW}====================================================${NC}"
