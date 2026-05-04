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

# Warn and confirm before touching kernel modules
any_loaded=false
for mod in "${modules[@]}"; do
    if lsmod | grep -q "^$mod"; then
        any_loaded=true
        break
    fi
done
if $any_loaded; then
    echo -e "${YELLOW}WARNING: One or more AF_ALG modules are loaded and will be removed.${NC}"
    echo -e "${YELLOW}This may break kernel crypto services (IPsec, LUKS, WireGuard, etc.).${NC}"
    echo -n "Continue with module removal? [y/N]: "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Module removal aborted by user.${NC}"
        exit 0
    fi
fi

for mod in "${modules[@]}"; do
    if lsmod | grep -q "^$mod"; then
        echo -e "${YELLOW}DANGER: $mod is currently LOADED in RAM.${NC}"
        # Check if any other modules depend on this one
        deps=$(lsmod | grep -v "^$mod" | grep "$mod" | awk '{print $1}' | tr '\n' ' ')
        if [ -n "$deps" ]; then
            echo -e "${YELLOW}  -> Dependents detected: $deps (may fail removal)${NC}"
        fi
        modprobe -rv $mod 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SUCCESS: $mod has been evicted.${NC}"
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
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${YELLOW}UNVERIFIED: python3 is not installed. Cannot test AF_ALG socket.${NC}"
    echo -e "${YELLOW}RESULT: Install python3 or verify manually with: socket(AF_ALG, SOCK_SEQPACKET, 0)${NC}"
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
    if [ $RC -eq 1 ]; then
        echo -e "${GREEN}VERIFIED: System successfully rejected the AF_ALG socket request.${NC}"
        echo -e "${GREEN}RESULT: The LPE exploit vector is now structurally blocked.${NC}"
    elif [ $RC -eq 0 ]; then
        echo -e "${RED}ALERT: Kernel still accepts AF_ALG socket creation!${NC}"
        echo -e "${RED}RESULT: System remains VULNERABLE.${NC}"
    else
        echo -e "${YELLOW}UNVERIFIED: Python socket module unavailable.${NC}"
        echo -e "${YELLOW}DETAIL: $RESULT${NC}"
        echo -e "${YELLOW}RESULT: Cannot confirm AF_ALG status automatically.${NC}"
    fi
fi

echo -e "\n${YELLOW}====================================================${NC}"
