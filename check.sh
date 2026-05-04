#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   System Structural Integrity Audit (SSIA) v1.0    ${NC}"
echo -e "${YELLOW}====================================================${NC}"

# 1. Process Authority & Capabilities
echo -e "\n[Layer 1: Process Context]"
echo -n "Current UID/GID: "
id | cut -d' ' -f1,2

echo -n "Effective Capabilities: "
if command -v capsh >/dev/null; then
    capsh --print | grep "Current" | cut -d'=' -f2
else
    echo "N/A (capsh not found)"
fi

# 2. Socket-Level Attack Surface (The "AF_ALG" Entry Point)
echo -e "\n[Layer 2: Communication Interface]"
echo -n "AF_ALG (Crypto API) Accessibility: "
# AF_ALG=38. SOCK_SEQPACKET=5.
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${YELLOW}UNKNOWN (python3 not installed — cannot test AF_ALG socket)${NC}"
    echo -e "  > Install python3 or manually test: socket(AF_ALG, SOCK_SEQPACKET, 0)"
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
        echo -e "${RED}EXPOSED (Unprivileged users can reach Kernel Crypto API)${NC}"
        echo -e "  > Risk: Direct vector for CVE-2026-31431 (copy-fail)${NC}"
    elif [ $RC -eq 1 ]; then
        echo -e "${GREEN}SECURE (Socket creation denied)${NC}"
    else
        echo -e "${YELLOW}UNKNOWN (Python socket module unavailable — cannot test AF_ALG socket)${NC}"
        echo -e "  > Detail: $RESULT"
    fi
fi

# 3. Information Leakage (Kernel Address Space)
echo -e "\n[Layer 3: Information Leakage]"
echo -n "Kernel Pointer Visibility (kptr_restrict): "
KPTR=$(cat /proc/sys/kernel/kptr_restrict 2>/dev/null)
if [ "$KPTR" == "0" ] || [ -z "$KPTR" ]; then
    echo -e "${RED}VULNERABLE (Value: $KPTR)${NC}"
else
    echo -e "${GREEN}PROTECTED (Value: $KPTR)${NC}"
fi

echo -n "Dmesg Access (dmesg_restrict): "
DMESG=$(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null)
if [ "$DMESG" == "0" ]; then
    echo -e "${RED}EXPOSED (Attackers can see kernel logs)${NC}"
else
    echo -e "${GREEN}RESTRICTED${NC}"
fi

# 4. Mandatory Access Control (MAC)
echo -e "\n[Layer 4: Security Policy]"
echo -n "SELinux Status: "
if command -v getenforce >/dev/null; then
    STATUS=$(getenforce)
    if [ "$STATUS" == "Enforcing" ]; then
        echo -e "${GREEN}Enforcing${NC}"
    else
        echo -e "${RED}$STATUS${NC}"
    fi
else
    echo -e "${YELLOW}Not Installed/Not Found${NC}"
fi

# 5. Filesystem Integrity
echo -e "\n[Layer 5: Mount Options]"
echo -n "/proc mount protection: "
mount | grep "proc on /proc" | grep -q "hidepid="
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Protected (hidepid in use)${NC}"
else
    echo -e "${YELLOW}Standard (Information leakage possible)${NC}"
fi

echo -e "\n${YELLOW}====================================================${NC}"
