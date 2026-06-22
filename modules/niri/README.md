# Niri Window Manager Module

**offsec-workstation** - Scrollable tiling Wayland compositor for offensive security workflows

---

## Overview

Niri is a modern Wayland compositor with unique scrollable tiling that never resizes windows unexpectedly. This module provides a complete, reproducible Niri setup optimized for offensive security work.

### Why Niri?

- **Scrolling layout** - Infinite horizontal workspace, no forced window resizing
- **Dynamic workspaces** - Per-monitor workspaces that adapt to your workflow
- **Superior Wayland support** - Better performance and security than X11
- **Overview mode** - GNOME-like window management with trackpad gestures
- **Containerized workflows** - Seamless integration with Podman security profiles

---

## Features

✅ **Modular configuration** - Separate files for input, keybinds, themes, window rules  
✅ **OPSEC theme switching** - Quick visual theme changes (dark/light/default)  
✅ **Focus-or-spawn** - Smart window focusing prevents duplicate windows  
✅ **Container integration** - One-command access to isolated tool environments  
✅ **Nvidia support** - Full hardware acceleration with GTX 1650  
✅ **Transparent terminals** - 90% opacity for wallpaper visibility  
✅ **DMS integration** - Modern bar with wallpaper picker and system tray  

---

## Installation

### Prerequisites

```bash
# Core packages (from packages.list)
sudo pacman -S niri xwayland-satellite swaync wl-clipboard \
               brightnessctl playerctl pavucontrol swaybg \
               swaylock swayidle polkit pipewire wireplumber

# Fonts
sudo pacman -S ttf-nerd-fonts-symbols-mono noto-fonts-emoji ttf-meslo-nerd

# AUR packages
yay -S walker-bin dms-shell-niri
```

### Nvidia Setup (GTX 1650)

```bash
# Enable nvidia-drm modesetting
echo "options nvidia-drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf

# Add to kernel command line
sudo nvim /etc/default/grub
# Add: nvidia-drm.modeset=1 nvidia-drm.fbdev=1 to GRUB_CMDLINE_LINUX_DEFAULT

# Regenerate
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo mkinitcpio -P
sudo reboot
```

### Install Dotfiles

```bash
# Clone or pull latest
cd ~/Github/offsec-workstation

# Run installer
./modules/niri/install.sh

# Verify
niri validate
```

---

## Configuration Structure

```
~/.config/niri/
├── config.kdl              # Main config (imports includes/)
├── includes/
│   ├── input.kdl           # Keyboard, mouse, touchpad
│   ├── keybinds.kdl        # All keybindings
│   ├── window-rules.kdl    # App-specific rules
│   ├── theme-default.kdl   # Default theme
│   ├── theme-opsec-dark.kdl   # Low-light theme
│   ├── theme-opsec-light.kdl  # High-contrast theme
│   └── local.kdl           # Machine-specific (gitignored)
└── scripts/
    ├── focus-or-spawn.sh   # Smart window focusing
    ├── container-launch.sh # Container access
    └── theme-switch.sh     # Theme switching
```

---

## Keybindings

**Full cheatsheet:** See [KEYBINDS.md](../../docs/KEYBINDS.md)

### Essential Shortcuts

| Key | Action |
|-----|--------|
| `Super+Return` | New terminal |
| `Super+D` | Application launcher (DMS) |
| `Super+B` | Browser (focus-or-spawn) |
| `Super+F` | File manager (yazi) |
| `Super+N` | Notes (Obsidian) |
| `Super+Q` | Close window |
| `Super+Space` | Toggle floating |
| `Super+Shift+F` | Fullscreen |

### Navigation (Vim-style)

| Key | Action |
|-----|--------|
| `Super+H/J/K/L` | Focus left/down/up/right |
| `Super+Shift+H/J/K/L` | Move window |
| `Super+Ctrl+H/J/K/L` | Resize window |

### Workspaces

| Key | Action |
|-----|--------|
| `Super+1-5` | Switch to workspace |
| `Super+Shift+1-5` | Move window to workspace |
| `Super+O` | Toggle overview |

---

## Theme Switching

Quick theme changes for different lighting conditions:

```bash
# Dark theme (low-light OPSEC)
~/.config/niri/scripts/theme-switch.sh dark

# Light theme (high-contrast)
~/.config/niri/scripts/theme-switch.sh light

# Default theme
~/.config/niri/scripts/theme-switch.sh default
```

**What changes:**
- Niri border colors
- Ghostty terminal colors
- DMS bar theme (future: via matugen)

---

## Container Workflows

Access Podman security profiles seamlessly:

```bash
# Via DMS launcher (Super+D):
# Type: "offsec-ad" → launches AD container

# Manual launch:
~/.config/niri/scripts/container-launch.sh ad

# Available profiles:
# - toolbox (general tools)
# - ad (Active Directory attacks)
# - re (Reverse engineering)
# - web (Web application testing)
```

---

## Window Management

### Scrolling Layout

Niri's unique feature: windows never resize unexpectedly. New windows scroll horizontally.

**Navigation:**
- `Super+H/L` - Scroll left/right through windows
- `Super+Home/End` - Jump to first/last column

### Tabbed Columns

Stack multiple windows in one "tab column":

1. `Super+W` - Toggle tabbed mode for current column
2. `Super+[` or `Super+]` - Merge window left/right
3. `Super+,` or `Super+.` - Pull/push window into column

### Overview Mode

- `Super+O` or `Super+Tab` - Toggle overview
- Mouse drag - Move windows between workspaces
- Four-finger swipe up (trackpad) - Open overview

---

## Troubleshooting

### Niri Freezes on Launch

**Symptom:** Black screen on TTY2, logs show `Error::DeviceMissing`

**Fix:**
```bash
# 1. Check nvidia-drm loaded
lsmod | grep nvidia_drm

# 2. Verify modeset enabled
cat /sys/module/nvidia_drm/parameters/modeset  # Should show Y

# 3. Check for blacklist
ls /etc/modprobe.d/ | grep nvidia

# 4. Remove any blacklist files
sudo rm /etc/modprobe.d/blacklist-nvidia.conf

# 5. Rebuild initramfs
sudo mkinitcpio -P && sudo reboot
```

### DMS Not Launching

```bash
# Check if quickshell is installed
pacman -Q dms-shell-niri

# Verify symlinks
ls -la ~/.config/quickshell/

# Should have:
# shell.qml -> /etc/xdg/quickshell/dms/shell.qml
# dms -> /etc/xdg/quickshell/dms

# Recreate if missing
ln -sf /etc/xdg/quickshell/dms/shell.qml ~/.config/quickshell/shell.qml
ln -sf /etc/xdg/quickshell/dms ~/.config/quickshell/dms
```

### Focus-or-Spawn Not Working

```bash
# Test manually
~/.config/niri/scripts/focus-or-spawn.sh --app-id brave-browser brave

# Check if jq is installed
sudo pacman -S jq

# Verify window detection
niri msg -j windows | jq '.[] | {title, app_id}'
```

---

## Advanced Configuration

### Monitor Setup (local.kdl)

```kdl
// Example: 180Hz gaming monitor
output "DP-1" {
    mode "2560x1440@180.000"
    scale 1.0
    position x=0 y=0
}
```

### Custom Window Rules

```kdl
// Float specific apps
window-rule {
    match app-id="pavucontrol"
    open-floating true
}

// Open on specific workspace
window-rule {
    match app-id="obsidian"
    open-on-workspace "4"
}
```

### Matugen Theme Generation (Future)

DMS includes matugen configs for wallpaper-based theming:

```bash
# Generate from wallpaper
matugen image ~/wallpaper.jpg -m dark -t scheme-content \
    -c /etc/xdg/quickshell/dms/matugen/configs/

# Configs available for:
# - niri.toml
# - ghostty.toml
# - hyprland.toml
# - kitty.toml
# (and 15+ others)
```

---

## Performance

**System:** i3-10105F, 32GB RAM, GTX 1650  
**Compositor:** Niri 25.11  
**FPS:** 60Hz (capped, configurable up to 180Hz)  
**Memory:** ~150MB (Niri + DMS + swaync)  
**Latency:** <10ms input lag

---

## Migration from Sway

Niri uses different paradigms:

| Sway | Niri Equivalent |
|------|-----------------|
| `$mod+h/j/k/l` focus | Same (Vim keys) |
| Container layout | Tabbed columns (`Super+W`) |
| Workspace switching | Same (`Super+1-5`) |
| Float toggle | Same (`Super+Space`) |
| Split h/v | Auto-scrolling (no manual split) |
| Resize mode | `Super+Ctrl+H/J/K/L` |

**Key difference:** No manual splits! Niri scrolls horizontally automatically.

---

## Contributing

Found a bug or have an enhancement? Open an issue:  
https://github.com/CR1MS0N-Operator/nightforge/issues

---

## Resources

- [Niri Wiki](https://github.com/niri-wm/niri/wiki)
- [Niri Configuration](https://yalter.github.io/niri/Configuration:-Introduction)
- [DMS Documentation](https://github.com/dankernel/dms)
- [Nvidia Wayland Guide](https://github.com/niri-wm/niri/wiki/Nvidia)

---

**Last Updated:** March 1, 2026  
**Niri Version:** 25.11  
**Status:** Production-ready ✅
