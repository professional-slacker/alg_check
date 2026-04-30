## ⚠️ Important Disclaimer: Structural Hardening Risks

This tool implements **Structural Blocking** to mitigate **CVE-2026-31431** by physically renaming kernel modules and purging them from memory. Before use, please be aware of the following architectural risks:

*   **Kernel Update Volatility**: Hardening effects are **temporary**. A kernel update will deploy fresh, vulnerable modules under a new `/lib/modules/` directory, rendering the previous obstruction void.
*   **Functional Side Effects**: Disabling `AF_ALG` (Kernel Crypto API) may break specific applications or services that rely on kernel-level hardware acceleration (e.g., specialized VPNs, disk encryption utilities, or custom security tools).[cite: 3]
*   **Mitigation vs. Patching**: This is a **workaround**, not a permanent patch. It is intended to bridge the gap until a distribution-provided patched kernel is available.

**Use at your own risk.** Always verify your system's critical functions after running `solution.sh`.[cite: 3]

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

## ⚠️ WARNING

**Running `solution.sh` on a live system that actively uses AF_ALG (e.g., a system with IPsec, dm-crypt/LUKS, or any hardware crypto offload) will instantly break all kernel crypto operations.** This includes:

- IPsec VPN connections and WireGuard
- Disk encryption (LUKS/dm-crypt)
- TLS termination using kernel-backed crypto
- Any container or application relying on `algif_*` socket interfaces

The script force-unloads AF_ALG kernel modules. Kernel crypto operations will fail until reboot. This script is intended **only for air-gapped, non-production, or disposable systems** for testing and analysis purposes. Do not run it on production or critical infrastructure.

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
