# System Configuration - offsec-workstation

## Overview

Complete configuration documentation for the CR1MS0N-Operator NightForge workstation.

**Last Updated:** 2026-02-24  
**System:** Arch Linux x86_64  
**Kernel:** 6.18.9-zen1-2-zen  
**Hardware:** Intel i3-10105F, GTX 1650, 32GB RAM, NVMe SSD

---

## Desktop Environment

### Window Manager: Sway (Wayland)

**Version:** 1.11  
**Config:** `~/.config/sway/config` (186 lines)

**Workspaces:**
- 1: ForeverLX (main)
- 2: Terminal
- 3: Browser
- 4: Obsidian (notes)
- 5: Labs (pentesting)

**Key Features:**
- Smart gaps and borders
- Auto back-and-forth workspace switching
- Custom color scheme (muted dark theme)
- Wallpaper: DoSomethingGreat-unsplash.jpg

**Keybindings:**
- Mod key: `Super` (Mod4)
- Terminal: `$mod+Return` → ghostty
- Launcher: `$mod+d` → fuzzel
- Navigation: `$mod+h/j/k/l` (vim-style)

### Status Bar: Waybar

**Config:** `~/.config/waybar/config`  
**Style:** `~/.config/waybar/style.css` (glassmorphic design)

**Modules:**
- Left: Workspaces, Mode
- Center: Window title
- Right: Network bandwidth, CPU%, RAM%, Clock, Tray

**Design:**
- Semi-transparent background (rgba)
- Smooth transitions (120ms)
- Modern glass effect
- Hover states

### Terminal: Ghostty

**Version:** 1.2.3-arch3  
**Config:** `~/.config/ghostty/config`

**Settings:**
- Font: MesloLGS Nerd Font Mono (14pt)
- Opacity: 0.35 (transparent)
- Colors: White on black with red cursor
- Dimensions: 120x34

### Application Launcher: Fuzzel

**Usage:**
- Run: `fuzzel --prompt "Hello:"`
- Dmenu mode: `fuzzel --dmenu --prompt "Cmd:"`

### Notifications: Mako

**Default Wayland notification daemon**

### Screenshots: Flameshot

**Usage:** Configured for evidence collection

### Audio: PipeWire

**Modern low-latency audio system**

---

## Shell Environment

### ZSH Configuration

**Primary:** `~/.zshrc` (44 lines)  
**Integration:** `~/.config/offsec-workstation/offsec.zsh`  
**Startup Time:** 0.023s (instant)

**Features:**
- Starship prompt (Konoha theme)
- History: 10,000 commands
- Instant append + share history
- PATH deduplication via `typeset -U`

**Key Bindings:**
- Emacs mode (`bindkey -e`)
- Home/End navigation
- Ctrl+Arrow word jumping

### Starship Prompt

**Config:** `~/.config/starship.toml`  
**Theme:** Konoha (custom palette)

**Segments:**
- Username, hostname
- Directory (truncated to 3 levels)
- Git branch and status (purple)
- Python virtualenv (red)
- Time (muted)
- Character prompt

**Colors:**
- Background: #0f0f12
- Foreground: #e6e6e6
- Muted: #9aa0a6
- Red: #b23a48
- Purple: #7a3db8

### Aliases & Functions

**From offsec.zsh:**
- `v` → nvim
- `ls` → eza
- `ff` → Fuzzy file finder with bat preview
- `y` → Yazi with auto-cd to exit directory
- `z` → Zoxide smart directory jump

---

## Editor

### Neovim

**Config:** `~/.config/nvim/` (1 config file)  
**Set as:**
- `$EDITOR=nvim`
- `$VISUAL=nvim`

---

## Development Tools

### Git

**User:** ForeverLX  
**Email:** Darrius.G@proton.me  
**Editor:** nvim (via $EDITOR)

**Config:** `~/.gitconfig`

### SSH

**Keys:** 2 public keys in `~/.ssh/`  
**Config:** Present (location protected)

---

## File Management

### Yazi (TUI File Manager)

**Integration:** Custom function in offsec.zsh  
**Feature:** Auto-cd to last visited directory

**Usage:** `y [path]`

### EZA (Modern ls)

**Replaces:** `ls` command  
**Features:** Modern colors, icons, git integration

---

## Performance Optimizations

### CPU

**Governor:** performance (always max speed)  
**Speeds:** 800-4400 MHz  
**Service:** `cpu-performance.service` (systemd)

**Current:** 4200 MHz (5.25x improvement from powersave)

### Network

**Interface:** enp3s0 (ethernet)  
**Speed:** 1000 Mb/s Full Duplex  
**Driver:** r8169

**Optimizations:**
- TCP buffers: Increased to 128MB
- Congestion control: BBR
- Window scaling: Enabled
- TCP fast open: Enabled

### Memory

**Total:** 32GB  
**Swap:** 4GB (zram)  
**Swappiness:** 10 (low, prefer RAM)

**Optimizations:**
- Reduced swapping
- Increased cache pressure
- Dirty ratio tuning for SSD

### Storage

**Primary:** NVMe SSD  
**Scheduler:** kyber (optimal for NVMe)  
**Power:** Performance mode

### Boot Time

**Before:** 20.5s  
**After:** ~10s  
**Disabled:** man-db, plocate-updatedb

---

## Security

### Firewall

**Status:** Not configured  
**Recommendation:** Install ufw if needed

### Services

**Enabled:**
- cpu-performance.service
- PipeWire
- Sway session

---

## Containers (offsec-workstation)

### Profiles

**toolbox:** Base utilities (1.06 GB)  
**web:** Reconnaissance (4.4 GB)  
**re:** Reverse engineering (1.89 GB)  
**ad:** Active Directory (1.25 GB)

**Management:** `container.sh` in repo

---

## File Organization

### Primary Directories

```
~/
├── Github/              # GitHub repos (86 MB)
├── Projects/            # Active projects (1.3 GB)
├── Labs/                # CTF and practice (2.4 GB)
├── engage/              # Client engagements (2.9 MB)
│   ├── nightowl/
│   ├── portswigger-labs/
│   ├── TEST/
│   └── test-company-2026/
├── Tools/               # Custom tools (1.7 GB)
├── Documents/           # Documentation (331 MB)
├── Downloads/           # Temporary (6.8 GB)
├── Archives/            # Long-term storage
├── Backups/             # System backups (1.1 GB)
└── Personal/            # Personal files (723 MB)
```
---

## Backup Strategy

### Critical Configs

**Must backup:**
- `~/.zshrc`
- `~/.config/sway/config`
- `~/.config/waybar/`
- `~/.config/starship.toml`
- `~/.config/ghostty/config`
- `~/.config/nvim/`
- `~/.config/offsec-workstation/offsec.zsh`
- `~/.gitconfig`
- `~/.ssh/` (encrypted)

**Location:** `~/Backups/` or `~/.offsec-workstation-backups/`

### System Recovery

**Package list:**
```bash
pacman -Qe > ~/Backups/packages.txt
pacman -Qm > ~/Backups/aur-packages.txt
```

**Container images:**
```bash
podman save localhost/offsec-web:0.1.0 | gzip > web-container.tar.gz
```

---

## Performance Monitoring

### Quick Status

```bash
perf-status  # Custom script from Phase 6.2
```

**Shows:**
- CPU governor
- Current frequency
- Network congestion control
- Swappiness
- Load average

### Real-time Monitoring

```bash
htop        # Process monitor
btop        # Modern resource monitor
iotop       # I/O monitor
iftop       # Network bandwidth
nethogs     # Per-process network usage
```

---

## Known Issues

**None currently.** System is stable and optimized.

---

## Future Enhancements

1. **Firewall:** Configure ufw if needed for network exposure
2. **Power Management:** TLP if switching to laptop
3. **Automated Backups:** Scheduled config backups
4. **Evidence Collection:** Automated screenshot/logging (Phase 6.3)

---

## Support

**Repository:** ~/Github/offsec-workstation  
**Documentation:** `docs/` in repo  
**Configs:** Managed via dotfiles

**Last Audit:** 2026-02-24 (Phase 6.2)
