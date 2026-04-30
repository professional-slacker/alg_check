# SSIA - System Structural Integrity Audit

A tool kit for discovering, diagnosing, and containing LPE (Local Privilege Escalation) vectors through the Linux Kernel Crypto API (`AF_ALG`).

## Overview

This repository provides five scripts that form a **diagnose → contain → verify** workflow against privilege escalation attacks via `AF_ALG` (`socket(38, 5, 0)`):

- **`check.sh`** — Multi-layer security posture audit (runs unprivileged)
- **`sol.sh`** — Unloads AF_ALG kernel modules + switches SELinux to enforcing (root required)
- **`solution.sh`** — Force-evicts AF_ALG modules from memory + checks for physical module files (root required)
- **`s.sh`** — Lightweight variant of `solution.sh`: memory purge + physical file check + final test (root required)
- **`copy_fail_exp.py`** — CVE-2026-31431 proof-of-concept exploit (requires AF_ALG access)

## CVE-2026-31431

`copy_fail_exp.py` is a proof-of-concept LPE exploit targeting a memory corruption vulnerability in the Linux Kernel Crypto API (`AF_ALG`). When an authenticated encryption (AEAD) `sendmsg` call fails during data transmission, the internal buffer handling is flawed, enabling arbitrary code execution.

**Attack flow:**
1. Create an `AF_ALG` socket (`socket(38, 5, 0)`)
2. Bind with an AEAD algorithm
3. Use `splice()` to send file content through the encrypting socket
4. Recover the first 32 bytes of encrypted data
5. Escalate privileges via KAICI (Kernel Anonymous Credential Injection)

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

Three options depending on your needs:

```bash
# Option 1: Unload modules + enforce SELinux
sudo ./sol.sh

# Option 2: Force-evict modules + verify physical files (verbose output)
sudo ./solution.sh

# Option 3: Lightweight — purge + file check + final test
sudo ./s.sh
```

### Behavioral differences

| Operation | sol.sh | solution.sh | s.sh |
|-----------|--------|-------------|------|
| Module unloading | `modprobe -r` (standard) | `modprobe -rv` (verbose) | `modprobe -rv` (verbose) |
| SELinux enforcing | yes | no | no |
| Physical file check | no | yes | yes |
| AF_ALG socket test | yes | yes | yes |

## Requirements

- Linux (any distribution)
- `check.sh` requires no dependencies beyond POSIX shell and `/proc`/`/sys`
- All other scripts require root privileges
- `copy_fail_exp.py` requires AF_ALG socket access (i.e., a non-hardened kernel)

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
