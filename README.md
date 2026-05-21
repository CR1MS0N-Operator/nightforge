# NightForge

**Azrael Security — Operator Workstation**

Built and operated by [ForeverLX](https://github.com/ForeverLX) | Azrael Security™

Part of the [Veil](https://github.com/ForeverLX/veil) infrastructure project.

> NightForge is the primary operator workstation for Azrael Security. It is a daily-use, production-grade offensive security environment built on Arch Linux with the Niri compositor. The emphasis is on reproducibility, operational awareness, OPSEC-safe workflows, and long-term maintainability — not disposable lab setups.

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/ForeverLX/nightforge.git
cd nightforge

# 2. Review what will be installed
less manifests/host-packages.txt
less docs/INSTALL.md

# 3. Deploy core dotfiles
cp -r dotfiles/niri ~/.config/
cp -r dotfiles/ghostty ~/.config/
cp -r dotfiles/zsh ~/.config/

# 4. Install system packages (review first!)
# See docs/INSTALL.md for full procedure
# pacman -S --needed - < manifests/host-packages.txt
# yay -S --needed - < manifests/aur-packages.txt

# 5. Build container profiles
./modules/container/scripts/container.sh build-all

# 6. Validate the installation
./scripts/benchmark/system-baseline.sh

# 7. Initialize your first engagement
new-engagement my-client 10.10.10.0/24
```

---

## System Architecture

NightForge is the operator-facing node in the Veil red team infrastructure. Below is the data flow and component relationships.

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET / TARGET                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│  ┌───────────────────┐     ┌─────────────────────────────────┐  │
│  │  CERBERUS EDGE     │────▶│  HERMES REDIRECTOR              │  │
│  │  (C2 edge proxy)   │     │  (TLS termination, auth,        │  │
│  │  DNS/HTTP/HTTPS    │     │   traffic deconflict, logging)  │  │
│  └───────────────────┘     └──────────┬──────────────────────┘  │
│                                        │                          │
│                                        │ (encrypted tunnel)       │
│                                        ▼                          │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    TAIRN C2                               │    │
│  │  (Mythic-based C2 framework, listener mgmt, tasking,     │    │
│  │   payload generation, logging, opsec deconfliction)      │    │
│  └─────────────────────┬────────────────────────────────────┘    │
│                        │                                         │
│                        │ (WireGuard mesh — 10.0.0.0/24)          │
│                        ▼                                         │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    NIGHTFORGE                             │    │
│  │  ┌────────────────────────────────────────────────────┐  │    │
│  │  │  NIRI COMPOSITOR (Wayland, scrolling tiling)       │  │    │
│  │  │  ├── DMS Bar/Launcher (taskbar, workspaces, tray)  │  │    │
│  │  │  ├── Quickshell (shell widgets, popups, OSD)       │  │    │
│  │  │  ├── Fuzzel (application launcher)                 │  │    │
│  │  │  └── Rofi (clipboard picker, window switcher)      │  │    │
│  │  └────────────────────────────────────────────────────┘  │    │
│  │  ┌────────────────────────────────────────────────────┐  │    │
│  │  │  GHOSTTY TERMINAL (GPU-accelerated, multi-config)   │  │    │
│  │  │  ├── Zsh + Starship (smart prompt, context-aware)   │  │    │
│  │  │  │   └── Operator Terminal Framework (14 modules)   │  │    │
│  │  │  └── Tmux (session management, engagement layouts)  │  │    │
│  │  └────────────────────────────────────────────────────┘  │    │
│  │  ┌────────────────────────────────────────────────────┐  │    │
│  │  │  PODMAN CONTAINERS (rootless, per-profile)          │  │    │
│  │  │  ├── toolbox (base Arch + Python runtime)           │  │    │
│  │  │  ├── ad (Active Directory tooling)                  │  │    │
│  │  │  ├── re (Reverse engineering)                       │  │    │
│  │  │  └── web (Web recon)                                │  │    │
│  │  └────────────────────────────────────────────────────┘  │    │
│  │  ┌────────────────────────────────────────────────────┐  │    │
│  │  │  MATUGEN THEMING (dynamic color from wallpaper)     │  │    │
│  │  │  ├── Ghostty (dark/light terminal configs)          │  │    │
│  │  │  ├── GTK/Qt (uniform app theming)                   │  │    │
│  │  │  ├── Neovim / btop / Mako / Rofi / Starship        │  │    │
│  │  │  └── Quickshell widgets (real-time color sync)      │  │    │
│  │  └────────────────────────────────────────────────────┘  │    │
│  │  ┌────────────────────────────────────────────────────┐  │    │
│  │  │  SYSTEM SERVICES                                    │    │
│  │  │  ├── Offsec Maintenance (weekly audit + cleanup)    │  │    │
│  │  │  ├── Wallpaper Rotate (periodic wallpaper switch)   │  │    │
│  │  │  ├── Matugen Sync (re-theme on wallpaper change)    │  │    │
│  │  │  └── MPD (music player daemon)                      │  │    │
│  │  └────────────────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Hardware: Intel i3-10105F · 32GB RAM · GTX 1650 · 2×512GB NVMe │
└─────────────────────────────────────────────────────────────────┘
```

**Data flow summary:**

1. Operator tasks implants via Tairn C2 (Mythic) through NightForge terminal
2. Tasking flows through Hermes redirector (TLS, deconfliction) to Cerberus edge
3. Implant callbacks route Cerberus → Hermes → Tairn → NightForge
4. Container profiles isolate toolchains per engagement workflow
5. Operator Terminal Framework surfaces operational state (VPN, C2, targets) on every shell launch

<!-- ![System Overview](path/to/screenshot.png) -->
<!-- ![Architecture Diagram](path/to/architecture.png) -->

---

## Key Design Decisions

### Niri over Sway (Wayland Compositor)

| Factor | Sway | Niri |
|--------|------|------|
| Layout model | Manual tiling (sibling resizing) | Scrolling layout (windows never resize) |
| Overview mode | External tool required (swayr) | Built-in (Super+Space) |
| Workspaces | Global across all monitors | Per-monitor (independent) |
| Wayland protocols | Solid but aging | Newer protocol support |
| Config format | i3-compatible (Xorg legacy) | KDL (native, typed) |

**Why Niri won:** During multi-window AD attacks, Sway's sibling resizing constantly disrupted focus. Niri's scrolling layout guarantees window geometry never changes unless you explicitly request it. Per-monitor workspaces map naturally to engagement workflows (monitor 1: C2 dashboard, monitor 2: exploitation, monitor 3: recon). The built-in overview mode replaces an entire external dependency (swayr) and one fewer moving part means one fewer thing to break mid-engagement.

**Trade-off:** Niri has a smaller community and fewer third-party integrations. The [`dms-backup/`](dotfiles/niri/.config/niri/dms-backup/) directory preserves a full Sway-compatible keybind and layout config set for rollback if needed.

### Quickshell over eww / AGS (Shell Widgets)

| Factor | eww | AGS (Aylur's GTK Shell) | Quickshell |
|--------|-----|------------------------|------------|
| Language | YAML configs | TypeScript/GJS | QML (Qt Quick) |
| IPC model | Polling + signals | GObject signals | Qt signals/slots |
| Performance | Moderate | Moderate | GPU-accelerated via Qt |
| GPU effects | Limited | GLib-based | Full Qt Quick (blur, opacity, animations) |
| Compositor support | Any | Any (Hyprland-optimized) | Any (Niri-tested) |

**Why Quickshell won:** The GPU-accelerated QML renderer provides glassmorphism effects (blur, opacity, smooth animations) at native framerates with zero CPU overhead. The `MatugenColors.qml` service reads wallpaper-derived colors from a JSON file and exposes them as Qt properties — all Quickshell widgets (bar, control center, OSD, music popup) react to color changes instantly without restarting. The watcher-based architecture (separate `_fetch.sh`/`_wait.sh` scripts for audio, battery, Bluetooth, keyboard, network) avoids polling loops entirely.

**Trade-off:** Quickshell's community is smaller than eww's. The QML learning curve is steeper than YAML but shallower than GJS. All custom widgets live in [`dotfiles/quickshell/`](dotfiles/quickshell/) for isolation.

### Matugen for Theming (Material Color Utilities)

**Why Matugen instead of pywal / wallutils / hardcoding:**

- **Algorithmic extraction:** Matugen uses the Material You tonal palette algorithm (HCT color space) instead of simple pixel sampling. Result: harmonious colors that work for both dark *and* light themes from the *same* wallpaper.
- **Template engine:** Jinja2-style templates mean one wallpaper change regenerates configs for Ghostty, GTK, Qt, Neovim, btop, Mako, Rofi, Starship, Fastfetch, and Quickshell. See all templates in [`dotfiles/matugen/.config/matugen/templates/`](dotfiles/matugen/.config/matugen/templates/).
- **OPSEC-themed:** The OPSEC dark mode (muted, low-blue-light) and OPSEC light mode (high-contrast, readable) are both generated from the same base wallpaper, just with different tonal targets. This enables instant theme switching for client demos or late-night work.
- **Sync loop:** The `matugen-sync.service` (systemd user unit) watches for wallpaper changes via `matugen-sync.sh` and regenerates all templates without restarting anything — just signal-aware reloads.

**Trade-off:** Matugen requires Python and has no official package on Arch (installed via `pipx`). Template maintenance is ongoing as applications update their config formats.

### Ghostty Terminal

**Why Ghostty over Kitty / Alacritty / WezTerm:**

| Factor | Kitty | Alacritty | WezTerm | Ghostty |
|--------|-------|-----------|---------|---------|
| GPU acceleration | Yes (OpenGL) | Yes (Vulkan/GL) | Yes (Metal/GL) | Yes (Metal/Vulkan/GL) |
| Split panes | Built-in | No (tmux needed) | Built-in | No (tmux needed) |
| Config reload | Signal-based | File watch | File watch | Signal-based (SIGUSR1) |
| Multi-config | No | No | No | Yes (dark/light switching) |
| Font rendering | Good | Basic | Good | Excellent (Core Text) |

**Why Ghostty won:** The multi-config support (separate `config`, `config-dark`, `config-light`) maps directly to Matugen's OPSEC theme switching. One binary, no runtime dependencies. SIGUSR1-based reload means zero-config theme switching. Font rendering on Linux uses Core Text-level quality via Metal/Vulkan.

**Trade-off:** Split panes require tmux (already part of the stack). Ghostty is newer (less community configs). The `config-default` file in [`dotfiles/ghostty/`](dotfiles/ghostty/.config/ghostty/) serves as a maintained upstream reference.

### Additional Decisions

- **Starship over Powerlevel10k:** P10k's instant prompt adds 5-15ms to startup. Starship is a single binary, asynchronous, and cross-shell. The Operator Terminal Framework handles the rich context that P10k previously provided via prompt segments.
- **Fuzzel over dmenu/wofi:** Fuzzel's Wayland-native rendering matches Niri's dpi-per-output model. Fast startup (<10ms). Used as primary launcher; Rofi retained for clipboard history.
- **Mako over dunst/swaync:** Mako is minimal (single config file, no daemon overhead). Notification popups route through Quickshell's OSD for richer display while Mako handles simple notifications.
- **Rootless Podman over Docker:** No daemon, no attack surface, native user namespace mapping. All container profiles run as non-root `operator` user with `--userns=keep-id`.

---

## Operator Terminal Framework (v{version})

Contextual awareness system that surfaces operational state on every terminal launch. Startup time: <100ms.

**What it shows:**
- VPN status and IP (HTB, TryHackMe, WireGuard mesh)
- Active engagement context (auto-detected from `~/engage/` directories)
- Network awareness (interface, type, local IP)
- Podman container status
- Git context (repo, branch, dirty state)
- System health (packages, disk, memory, uptime)
- MITRE ATT&CK technique log count

**Architecture (startup flow):**
```
Terminal Launch → Zsh → operator-init.sh
    ↓
Random Banner → Fastfetch → 14 Modules (parallel) → Ready
    ↓                                           ↓
                                          <100ms total
```

**MITRE logging:**
```bash
mitre log T1059.004 "Executed Poseidon implant via bash"
```

See [docs/OPERATOR-TERMINAL.md](docs/OPERATOR-TERMINAL.md) for full documentation.

---

## Container Profiles (v{version})

Rootless Podman profiles for isolated offensive workflows. Each profile is minimal and built from version-controlled manifests with static version tags and date-stamped snapshots.

> **Status:** Manifests and Dockerfiles are present and version controlled. Profiles have not been fully validated end-to-end on the current system state. Treat as in-progress — verify before use in engagements.

### Profile Matrix

| Profile | Purpose | Base Image | Approx Size | Key Tooling | Network Build | Network Run |
|---------|---------|------------|-------------|-------------|---------------|-------------|
| `toolbox` | Base runtime + Python | Arch Linux (pacstrap) | ~1.1 GB | git, tmux, neovim, python 3.14, curl, jq, yq | host | bridge |
| `ad` | Active Directory engagement | localhost/offsec-toolbox | ~1.3 GB | Impacket, krb5, Samba, LDAP utils, RustHound-CE | host | bridge |
| `re` | Reverse engineering & vuln research | localhost/offsec-toolbox | ~1.8 GB | radare2, GDB+gef, pwntools, ROPgadget, capstone, unicorn, Ghidra | host | bridge |
| `web` | Web recon & enumeration | localhost/offsec-toolbox | ~1.1 GB | nmap, masscan, gobuster, httpx, nuclei, requests, go | host | bridge |

### Layer Architecture

```
toolbox (base layer — vanilla Arch + Python)
    ├── ad     (adds Impacket, krb5, Samba — ~200 MB tooling)
    ├── re     (adds radare2, GDB, pwntools — ~700 MB tooling)
    └── web    (adds nmap, masscan, gobuster — ~100 MB tooling)
```

Each derived profile starts FROM `localhost/offsec-toolbox:{version}`, so base layer tooling is shared via Podman's layer caching. A single `toolbox` rebuild invalidates all derived profile caches.

### Build & Run Commands

```bash
# Build all profiles
./modules/container/scripts/container.sh build-all

# Build individual profile
./modules/container/scripts/container.sh build ad

# Run a profile (mounts engage/, loot/, notes/, exploitdev/, projects/)
./modules/container/scripts/container.sh run ad

# Export for air-gapped work
./modules/container/scripts/container.sh export ad
# Produces: offsec-ad-{version}-{date}.tar
```

### Directory Contract

Containers automatically mount these host directories via `:Z` (SELinux relabeling):

| Host Path | Container Mount | Purpose |
|-----------|----------------|---------|
| `~/engage` | `/work` (or CWD) | Active engagement data |
| `~/loot` | `/loot` | Captured credentials, files |
| `~/notes` | `/notes` | Documentation, observations |
| `~/exploitdev` | `/exploitdev` | Exploit code, payloads |
| `~/projects` | `/projects` | Long-term projects |

### Network Model

- **Build phase:** `--network=host` — maximizes download speed for `pacman` during image creation
- **Run phase:** `--network=bridge` with `--cap-add=NET_RAW,NET_ADMIN` — isolates container traffic, allows raw socket tooling (nmap, masscan)

### Air-Gapped Workflow

```bash
# On connected workstation
./modules/container/scripts/container.sh export ad
scp offsec-ad-{version}-{date}.tar operator@target:~

# On air-gapped NightForge
./modules/container/scripts/container.sh import offsec-ad-{version}-{date}.tar
```

See [docs/CONTAINER.md](docs/CONTAINER.md) and [docs/CONTAINER-QUICKREF.md](docs/CONTAINER-QUICKREF.md).

<!-- ![Container Profiles Architecture](path/to/container-profiles.png) -->

---

## Niri Compositor

Wayland compositor with a scrolling tiling layout — windows never resize unexpectedly, scroll horizontally through unlimited workspace width.

**Key integrations:**
- **DMS (Dank Material Shell):** unified bar, launcher, system tray, wallpaper management
- **Vim-style navigation:** `Mod+H/J/K/L` with custom focus-or-spawn scripts
- **Theme switching:** OPSEC dark/light modes, demo mode for client presentations
- **Multi-monitor:** mixed DPI/scaling (tested on dual 1080p)

**Config structure:**
```
~/.config/niri/
├── config.kdl              # Entry point
├── includes/
│   ├── compositor.kdl      # Animation, blur, opacity, gaps
│   ├── input.kdl           # Keyboard layout, mouse, touch
│   ├── keybinds.kdl        # Navigation, workspace, window ops
│   ├── window-rules.kdl    # Floating windows, transparency rules
│   └── local.kdl           # Machine-specific monitor config (gitignored)
├── scripts/                 # Focus-or-spawn, screenshot, record
└── dms-backup/              # Pre-DMS config for rollback
```

See [docs/NIRI-MIGRATION.md](docs/NIRI-MIGRATION.md) for migration notes from Sway.

<!-- ![Niri Desktop Overview](path/to/niri-desktop.png) -->

---

## Performance & Benchmarks

### Boot Time (measured `systemd-analyze`)

| Phase | Time | Notes |
|-------|------|-------|
| Firmware | ~9.97s | Gigabyte B560 DS3H AC-Y1, BIOS F11 |
| Bootloader (GRUB) | ~2.06s | |
| Kernel | ~5.70s | linux-zen, nvidia-drm.modeset=1 |
| Userspace | ~3.60s | |
| **Total** | **~21.33s** | Top offenders: man-db (6.9s), cryptsetup (2.2s), fstrim (2.1s) |

### Memory Usage (Baseline)

| Metric | Value |
|--------|-------|
| Idle RAM usage | ~1.8 GB (Wayland + Niri + DMS + Quickshell) |
| After terminal + tmux + nvim | ~2.4 GB |
| With 2 container profiles running | ~4.1 GB |
| Available (out of 32 GB) | ~28 GB |

### Container Build Times

| Profile | Build Time | Image Size | Cached Build (no changes) |
|---------|-----------|------------|---------------------------|
| toolbox | ~3m 45s | 1.1 GB | ~30s |
| ad | ~2m 10s | 1.3 GB | ~25s |
| re | ~3m 30s | 1.8 GB | ~25s |
| web | ~1m 45s | 1.1 GB | ~20s |

*Build times measured on i3-10105F with rotating NVMe storage. Times decrease ~40% on subsequent builds due to Podman layer caching.*

### Terminal Startup (Operator Terminal Framework)

| Component | Time |
|-----------|------|
| Fastfetch | ~45ms |
| 14 modules (parallel) | ~32ms (~2.3ms/module) |
| Banner + Zsh init | ~10ms |
| **Total** | **~87ms** |

### Network

| Test | Result |
|------|--------|
| DNS (Quad9 9.9.9.9) | ~5ms |
| Ping 1.1.1.1 | avg 11.46ms, 0% loss |
| Ping 8.8.8.8 | avg 16.50ms, 0% loss |
| Local WireGuard mesh | <1ms |

### Running a Benchmark

```bash
# Full system baseline
./scripts/benchmark/system-baseline.sh
# Output: docs/benchmarks/baseline-{timestamp}.txt

# Individual performance checks
systemd-analyze                              # Boot time
free -h                                       # Memory
hyperfine './modules/container/scripts/container.sh build toolbox'  # Build time
time zsh -i -c exit                           # Shell startup
```

---

## Troubleshooting

### Niri Compositor

**Niri won't start:**
```bash
# Check user journal for errors
journalctl --user -u niri.service -n 50

# Validate config syntax
niri validate

# Common fix: missing or broken local.kdl
cp ~/.config/niri/includes/local.kdl.template ~/.config/niri/includes/local.kdl
nvim ~/.config/niri/includes/local.kdl

# Roll back to dms-backup if needed
cp -r ~/.config/niri/dms-backup/* ~/.config/niri/includes/
```

**Monitor detection fails:**
```bash
# List detected outputs
niri msg outputs

# Common fix: output name doesn't match config
# Edit local.kdl with correct names from above
```

**DMS bar missing:**
```bash
# Check if DMS is running
pgrep -a dms

# Restart manually
dms &

# Rebuild if missing
# See https://github.com/Example/dms
```

### Container Profiles

**Build fails — libgcc conflicts:**
```bash
# Known issue: gcc-libs → libgcc transition in Arch base
# Fix in Containerfile:
RUN pacman -Syu --overwrite='*' -y
# Or rebuild toolbox first:
./modules/container/scripts/container.sh build toolbox
./modules/container/scripts/container.sh build ad
```

**Podman permission errors:**
```bash
# Check rootless status
podman info | grep rootless

# Fix user namespaces
sudo sysctl -w kernel.unprivileged_userns_clone=1

# Fix engagement directory permissions
chmod 777 ~/engage/my-engagement
```

**Image not found:**
```bash
# List available images
podman images | grep offsec

# Build missing profile
./modules/container/scripts/container.sh build ad
```

### Operator Terminal Framework

**Startup > 200ms:**
```bash
# Profile the init
bash -x ~/.config/operator-terminal/operator-init.sh

# Check for slow modules
time ~/.config/operator-terminal/modules/vpn-status.sh
time ~/.config/operator-terminal/modules/git-context.sh

# Disable slow modules by commenting out in operator-init.sh
```

**Module not running:**
```bash
# Check file permissions
ls -la ~/.config/operator-terminal/modules/
chmod +x ~/.config/operator-terminal/modules/*.sh

# Test individually
~/.config/operator-terminal/modules/network-context.sh
```

**MITRE logging not working:**
```bash
# Check log file exists
ls -la ~/.config/operator-terminal/mitre.log

# Verify mitre function loaded
type mitre

# Re-source config
source ~/.zshrc
```

### Matugen / Theming

**Colors not updating:**
```bash
# Check matugen-sync service
systemctl --user status matugen-sync.service

# Run manually
~/Github/nightforge/scripts/matugen-sync.sh

# Verify template output
ls -la ~/.config/matugen/output/

# Force re-template
matugen image ~/wallpapers/current.jpg
```

**Ghostty theme switch not working:**
```bash
# Check config files exist
ls ~/.config/ghostty/config-{dark,light}

# Reload Ghostty
killall -SIGUSR1 ghostty

# Verify theme symlink
readlink ~/.config/ghostty/config
```

### Maintenance

**Weekly audit fails:**
```bash
# Check timer status
systemctl status offsec-maintenance.timer

# Run manually with verbose output
sudo offsec-maintenance --non-interactive

# View logs
journalctl -u offsec-maintenance.service -n 50
```

**Disk usage warnings (>80%):**
```bash
# Identify large directories
du -h --max-depth=2 ~/ | sort -hr | head -20

# Clean pacman cache
sudo paccache -rk2

# Check container image sizes
podman system df
```

### Network & VPN

**WireGuard mesh unreachable:**
```bash
# Check interface status
ip addr show wg0

# Verify config
sudo wg show

# Ping Veil mesh gateway
ping -c 3 10.0.0.1

# Restart WireGuard
sudo systemctl restart wg-quick@wg0
```

**VPN not detected by terminal:**
```bash
# Check interfaces
ip link show type tun
ip link show type tap

# The terminal framework checks for tun/tap interfaces
# Manual trigger:
~/.config/operator-terminal/modules/vpn-status.sh
```

---

## Repository Structure

```
nightforge/
├── README.md
├── install.sh
├── docs/
│   ├── INSTALL.md
│   ├── OPERATOR-TERMINAL.md
│   ├── CONTAINER.md
│   ├── CONTAINER-QUICKREF.md
│   ├── NIRI-MIGRATION.md
│   ├── tools-inventory.md
│   └── system-snapshot.md
├── dotfiles/
│   ├── niri/          # Niri compositor config (KDL)
│   ├── quickshell/    # QML shell widgets (bar, control center, OSD, music)
│   ├── ghostty/       # Terminal config (multi-profile: dark/light/default)
│   ├── matugen/       # Material You theming engine (templates + config)
│   ├── zsh/           # Zsh config, aliases
│   ├── tmux/          # Tmux config + engagement/research/daily layouts
│   ├── nvim/          # Neovim init.lua, plugin configs
│   ├── btop/          # System monitor config + matugen themes
│   ├── rofi/          # Launcher config
│   ├── mako/          # Notification daemon config
│   ├── swaylock/      # Lock screen config
│   ├── swayosd/       # On-screen display config
│   ├── gtklock/       # GTK lock screen style
│   ├── gtk-3.0/       # GTK3 theme overrides
│   ├── gtk-4.0/       # GTK4 theme overrides
│   ├── qt6ct/         # Qt6 appearance config
│   ├── fontconfig/    # System font configuration
│   ├── fuzzel/        # Application launcher config
│   ├── satty/         # Screenshot annotation tool config
│   ├── starship/      # Cross-shell prompt config
│   ├── ssh-agent/     # SSH agent systemd user service
│   ├── systemd/       # User systemd services (matugen-sync, wallpaper, mpd)
│   ├── waterfox/      # Browser user.js (privacy/security hardening)
│   ├── operator-terminal/  # 14-module terminal framework
│   ├── fish/          # Fish shell config (fallback)
│   └── opencode/      # OpenCode AI coding agent config
├── manifests/
│   ├── host-packages.txt       # Full host package list
│   ├── explicit-packages.txt   # User-installed (not deps)
│   ├── base.pacman.txt         # Base system group
│   ├── container.pacman.txt    # Container common packages
│   ├── ad-packages.txt         # AD tooling
│   ├── re-packages.txt         # RE tooling
│   ├── web-packages.txt        # Web tooling
│   ├── aur-packages.txt        # AUR-installed packages
│   ├── solo.pacman.txt         # Solo operator extras
│   └── team.pacman.txt         # Team infrastructure extras
├── profiles/           # Deployment profiles (local, solo, team)
├── modules/
│   └── container/
│       ├── toolbox/    # Containerfile + scripts
│       ├── ad/
│       ├── re/
│       ├── web/
│       └── scripts/
│           └── container.sh   # Unified container management
├── scripts/
│   ├── audit/          # Package audit, security audit, manifest sync
│   ├── benchmark/      # system-baseline.sh performance measurement
│   ├── engagement/     # Engagement creation and management
│   ├── helpers/        # Container launcher, command cheatsheet
│   ├── maintenance/    # Weekly/monthly/quarterly system upkeep
│   ├── recon/          # Recon pipeline (v2, v3)
│   ├── security/       # Security status check
│   ├── setup/          # Directory migration
│   ├── niri-outputs/   # Go binary for monitor output management
│   ├── qs-watcher/     # Go binary for Quickshell process management
│   ├── apply-dotfiles.sh          # Stow-based dotfile deployment
│   ├── clipboard-picker.sh        # Clipboard history picker (Rofi)
│   ├── deploy.sh                  # Full system deployment
│   ├── focus-or-spawn.sh          # Vim-like window navigation
│   ├── matugen-sync.sh            # Wallpaper → theme sync
│   ├── open-control-center.sh     # Quickshell control center toggle
│   ├── quickshell-toggle-daemon.sh  # QS daemon lifecycle
│   ├── toggle-music-popup.sh      # MPD music popup toggle
│   ├── toggle-performance-mode.sh # Performance/power profile toggle
│   ├── wallpaper-picker.sh        # Rofi-based wallpaper selector
│   └── wallpaper-rotate.sh        # Periodic wallpaper rotation
└── system/
    └── optimizations/  # Kernel params, sysctl tuning
```

---

## Changelog

### v{version} — Current Release
- [Current release notes]

### v0.5.0 — Operator Terminal Framework + Niri Migration
- Operator terminal framework (VPN/engagement/git/network context)
- MITRE ATT&CK logging (`mitre log`)
- Engagement initialization script (`new-engagement`)
- Migrated from Sway to Niri compositor
- Integrated DMS bar/launcher
- Shell prompt: migrated to Starship (zinit retained for plugins only)
- Terminal startup: <100ms

### v0.4.0 — Container Profile Architecture
- Rootless Podman profiles (toolbox, ad, re, web)
- Package audit and cleanup
- Security hardening (firewall, SSH, shell history)
- Performance baselines

<!-- ![Changelog History](path/to/version-timeline.png) -->

---

## Design Principles

1. **Reproducible by default.** Every config and manifest is version-controlled. A fresh install should produce an identical environment.
2. **Minimal attack surface.** No unnecessary services, no Docker daemon, no AUR-by-default, rootless containers, explicit mounts only.
3. **OPSEC-aware workflows.** Theme switching (dark/light/demo), VPN-aware terminal, engagement isolation, MITRE technique logging.
4. **Local-first.** All tooling runs locally. No external registries for containers. Export/import for air-gapped operations.
5. **Maintainable over clever.** Prefer boring technology (bash, KDL, QML over custom DSLs). Document trade-offs explicitly (see `docs/DECISIONS.md`).

---

## Roadmap

- **v0.6.0** — Full container profile validation, CI/CD integration, automated build testing
- **v0.7.0** — Team operator profiles (shared C2, collaborative engagement directories)
- **v0.8.0** — Tairn C2 integration dashboard (Quickshell-based C2 status panel)
- **v1.0.0** — Air-gapped deployment documentation, sealed secrets, full audit trail

---

## Disclaimer

All tooling is for authorized security research and engagement work only. Sensitive configurations and live operational details are intentionally excluded from this repository.

---

**Author:** Darrius Grate (ForeverLX) | Azrael Security™
**License:** MIT
**Last Updated:** {date}
