# SSIA - System Structural Integrity Audit

A lightweight, zero-dependency Bash script for auditing Linux system security posture at the kernel and OS level. Runs on any Linux system with nothing but POSIX shell and basic `/proc` / `/sys` interfaces.

## Why

Cloud workloads, containers, and bare-metal servers share one thing in common: **the kernel attack surface is invisible from userspace**. SSIA checks the knobs and seams that standard vulnerability scanners miss — kernel pointer restrictions, AF_ALG socket availability, `/proc` mount hardening, and SELinux state.

This is the kind of check you run before deploying a workload, after a kernel update, or periodically on infrastructure nodes to catch configuration drift.

## Checks

| Check | What it looks for | Why it matters |
|-------|-------------------|----------------|
| **Process Context** | Current UID/GID and effective capabilities | Unprivileged context is expected; excess capabilities or root without need is a risk |
| **AF_ALG Crypto Socket** | Kernel crypto API accessibility via `socket(AF_ALG, ...)` | AF_ALG accessible from unprivileged namespaces is a CVE-2026-31431 vector |
| **kptr_restrict** | Kernel pointer visibility to userspace | `=0` leaks kernel addresses to unprivileged users, aiding ASLR bypass |
| **dmesg_restrict** | Access to kernel ring buffer | `=0` lets unprivileged users read kernel log, leaking pointers and sensitive info |
| **SELinux** | Enforcing / permissive / disabled state | A permissive or disabled SELinux is a major MAC gap |
| **/proc hidepid** | Whether `/proc` hides other processes' info | Without `hidepid=2`, any user can see all process command lines and env |

## Requirements

- Linux (any distribution with bash or POSIX sh)
- No external dependencies — uses only built-in shell commands and `/proc`/`/sys` interfaces

## Usage

```bash
chmod +x check.sh
./check.sh
```

Returns exit code:
- `0` — all checks pass (no issues found)
- `1` — one or more checks failed (issues detected)

## Example output

```
[PASS] Not running as root
[FAIL] AF_ALG socket accessible — potential CVE-2026-31431 vector
[PASS] kptr_restrict is set (2)
[FAIL] dmesg_restrict is not set (0)
[PASS] SELinux is enforcing
[PASS] /proc mounted with hidepid
```

## License

MIT
