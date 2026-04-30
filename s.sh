#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   ALG Memory Exorcist (Final Mitigation)           ${NC}"
echo -e "${YELLOW}====================================================${NC}"

# 1. Root Check
if [ $(id -u) -ne 0 ]; then
    echo -e "${RED}[Error] Root privileges required. Run this inside the '#' shell.${NC}"
    exit 1
fi

# 2. Force Unload from RAM
echo -e "\n[Step 1: Purging ALG from Memory]"
modules=("algif_hash" "algif_skcipher" "algif_aead" "algif_rng" "af_alg")
for mod in "${modules[@]}"; do
    if lsmod | grep -q "^$mod"; then
        modprobe -rv $mod 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SUCCESS: $mod has been purged from RAM.${NC}"
        else
            echo -e "${RED}FAILED: $mod is currently in use. A 'reboot' is mandatory.${NC}"
        fi
    else
        echo -e "INFO: $mod is not present in memory."
    fi
done

# 3. Verify Physical Blockage
echo -e "\n[Step 2: Verifying Physical File Absence]"
K_PATH="/lib/modules/$(uname -r)/kernel/crypto/af_alg.ko.xz"
if [ ! -f "$K_PATH" ]; then
    echo -e "${GREEN}SUCCESS: Physical module file is missing (Renamed).${NC}"
else
    echo -e "${RED}WARNING: Module file still exists at $K_PATH!${NC}"
fi

# 4. Final Security Test
echo -e "\n[Step 3: Final Integrity Test]"
# Attempting to create the socket as root (it should fail now)
python3 -c "import socket; socket.socket(38, 5, 0)" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${GREEN}COMPLETE: Defense Successful. System is now immune to this vector.${NC}"
else
    echo -e "${RED}FAILED: The socket was still created. The kernel is likely built-in.${NC}"
fi

echo -e "\n${YELLOW}====================================================${NC}"
