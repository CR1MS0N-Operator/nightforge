# NightForge Installation Guide

> See [README.md](../README.md#quick-start) for Quick Start instructions.
> See [docs/PROFILES.md](PROFILES.md) for deployment profile details.
> See [docs/SYSTEM-CONFIGURATION.md](SYSTEM-CONFIGURATION.md) for full system configuration.

## Prerequisites

- Arch Linux (base installation)
- `git`, `sudo` access
- ~30GB free disk space
- Internet connection

## Quick Install

```bash
# Clone the repository
git clone https://github.com/CR1MS0N-Operator/nightforge.git
cd nightforge

# Review manifests
less manifests/host-packages.txt
less manifests/aur-packages.txt

# Dry-run the installer
./install.sh --profile solo-operator --dry-run

# Install (review packages first)
./install.sh --profile solo-operator

# Deploy dotfiles
./scripts/apply-dotfiles.sh

# Build container profiles (optional)
./modules/container/scripts/container.sh build-all

# Run system baseline benchmark
./scripts/benchmark/system-baseline.sh
```

## Manual Install

See [scripts/deploy.sh](../scripts/deploy.sh) for dotfile deployment.
See [modules/container/scripts/container.sh](../modules/container/scripts/container.sh) for container management.

## Profiles

| Profile | Description |
|---------|-------------|
| `local-only` | Minimal local-first baseline |
| `solo-operator` | Full daily-drive workstation |
| `team-operator` | Standardized team deployment |

## Post-Install

1. Restart your shell
2. Run `new-engagement` to initialize your first engagement
3. See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) if issues arise
