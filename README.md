# SSIA - System Structural Integrity Audit

A tool kit for discovering, diagnosing, and containing LPE (Local Privilege Escalation) vectors through the Linux Kernel Crypto API (`AF_ALG`).

## Overview

This repository provides two scripts that form a **diagnose → contain → verify** workflow against privilege escalation attacks via `AF_ALG` (`socket(38, 5, 0)`):

- **`check.sh`** — Multi-layer security posture audit (runs unprivileged)
- **`solution.sh`** — Force-evicts AF_ALG modules from memory + checks for physical module files (root required)

## Checks

| Check | What it examines | Severity |
|-------|------------------|----------|
| **Process Context** | Current UID/GID and effective capabilities | Low |
| **AF_ALG Crypto Socket** | Kernel Crypto API accessibility via `socket(AF_ALG, ...)` | High |
| **kptr_restrict** | Kernel pointer visibility to userspace | Medium |
| **dmesg_restrict** | Kernel ring buffer access restriction | Medium |
| **SELinux** | Enforcing / Permissive / Disabled state | Medium |
| **/proc hidepid** | Whether `/proc` hides other processes' info | Low |

## Usage

### Audit (unprivileged)
```bash
./check.sh
```

### Containment (root required)

```bash
sudo ./solution.sh
```

## Requirements

- Linux (any distribution)
- `check.sh` requires no dependencies beyond POSIX shell and `/proc`/`/sys`
- `solution.sh` requires root privileges

## Mitigation

To definitively close the AF_ALG attack vector:

1. **Blacklist the kernel module** (most reliable):
   ```bash
   echo "blacklist af_alg" | sudo tee /etc/modprobe.d/af_alg-blacklist.conf
   ```
   Or rename the physical file:
   ```bash
   sudo mv /lib/modules/$(uname -r)/kernel/crypto/af_alg.ko.xz \
           /lib/modules/$(uname -r)/kernel/crypto/af_alg.ko.xz.bak
   ```

2. **Disable AF_ALG via sysctl**:
   ```bash
   sudo sysctl -w net.core.af_alg_disabled=1
   ```

3. **Block AF_ALG socket creation via SELinux / AppArmor policy**

4. **Disable unprivileged user namespaces** (container environments):
   ```bash
   sudo sysctl -w kernel.unprivileged_userns_clone=0
   ```

## License

MIT
