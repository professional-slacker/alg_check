#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   ALG Surface Hardening & Verification Tool        ${NC}"
echo -e "${YELLOW}====================================================${NC}"

# 1. Privilege Check
if [ $(id -u) -ne 0 ]; then
    echo -e "${RED}[Error] Insufficient privileges. Administrative (root) access required.${NC}"
    echo -e "Current user is not authorized to verify kernel structures."
    exit 1
fi

# 2. Kernel Memory State Analysis
echo -e "\n[Step 1: Analyzing Kernel Memory State (AF_ALG)]"
modules=("algif_hash" "algif_skcipher" "algif_aead" "algif_rng" "af_alg")
for mod in "${modules[@]}"; do
    if lsmod | grep -q "^$mod"; then
        echo -e "${YELLOW}DANGER: $mod is currently LOADED in RAM.${NC}"
        modprobe -rv $mod 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SUCCESS: $mod has been forcefully evicted.${NC}"
        else
            echo -e "${RED}FAILURE: $mod is BUSY. Kernel lock detected. REBOOT REQUIRED.${NC}"
        fi
    else
        echo -e "INFO: $mod is not present in memory (CLEAN)."
    fi
done

# 3. Physical Persistence Check
echo -e "\n[Step 2: Verifying Physical Storage Obstruction]"
K_PATH="/lib/modules/$(uname -r)/kernel/crypto/af_alg.ko.xz"
if [ ! -f "$K_PATH" ]; then
    echo -e "${GREEN}SUCCESS: Entry point (af_alg.ko.xz) is physically obstructed.${NC}"
else
    echo -e "${RED}CRITICAL: Exploit vector still exists on disk at: $K_PATH${NC}"
    echo -e "Manual renaming to *.bak is mandatory."
fi

# 4. Final System Call Integrity Test
echo -e "\n[Step 3: Verification of System Call Rejection]"
# Attempt to open an AF_ALG socket
python3 -c "import socket; socket.socket(38, 5, 0)" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${GREEN}VERIFIED: System successfully rejected the AF_ALG socket request.${NC}"
    echo -e "${GREEN}RESULT: The LPE exploit vector is now structurally blocked.${NC}"
else
    echo -e "${RED}ALERT: Kernel still accepts AF_ALG socket creation!${NC}"
    echo -e "${RED}RESULT: System remains VULNERABLE.${NC}"
fi

echo -e "\n${YELLOW}====================================================${NC}"
