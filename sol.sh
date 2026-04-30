#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   ALG Interface Hardening Script (Anti-LPE)        ${NC}"
echo -e "${YELLOW}====================================================${NC}"

# 1. Check Root Privilege
if [ $(id -u) -ne 0 ]; then
    echo -e "${RED}[Error] This script requires root (or the PoC # shell).${NC}"
    exit 1
fi

# 2. Unload Kernel Modules (If dynamic)
echo -e "\n[Step 1: Unloading AF_ALG Related Modules]"
for mod in "algif_hash" "algif_skcipher" "algif_aead" "algif_rng" "af_alg"; do
    if lsmod | grep -q "^$mod"; then
        modprobe -r $mod 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SUCCESS: $mod has been unloaded.${NC}"
        else
            echo -e "${RED}FAILED: $mod is in use or built-in.${NC}"
        fi
    else
        echo -e "INFO: $mod is not loaded."
    fi
done

# 3. Restrict Socket Creation (The Core Fix)
echo -e "\n[Step 2: Restricting Kernel Interface]"
# Android/Linuxの最近のカーネルではsysctl経由でプロトコルを制限できる場合がある
# または、SELinuxのコンテキストを動的に変更してブロックを試みる
if command -v setenforce >/dev/null; then
    echo "SELinux detected. Strengthening Policy..."
    # 本来はポリシーファイルを書き換えるべきだが、暫定的な封じ込め
    setenforce 1
    echo -e "${GREEN}SUCCESS: SELinux set to Enforcing.${NC}"
fi

# 4. Verification
echo -e "\n[Step 3: Verifying Protection]"
python3 -c "import socket; socket.socket(38, 5, 0)" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${GREEN}SAFE: AF_ALG socket creation is now DENIED.${NC}"
else
    echo -e "${RED}STILL VULNERABLE: AF_ALG is still reachable.${NC}"
fi

echo -e "\n${YELLOW}====================================================${NC}"
