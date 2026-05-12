# niri-modifications

Reproducible tooling for Niri window manager customizations used in the NightForge v3 operator workstation.

## Directory Structure

```
niri-modifications/
├── outputs/
│   ├── main.go              # Go source for display detector
│   └── niri-outputs          # Compiled binary
└── scripts/
    ├── keybinds-parser.sh    # Keybind cheatsheet generator
    ├── startups-parser.sh    # Startup services inspector
    ├── lock-screen.sh        # Screen lock launcher
    └── rotate-wallpaper.sh   # Wallpaper rotation + color sync
```

## outputs/

`niri-outputs` detects connected displays, their resolutions and refresh rates, and recommends scaling factors based on native resolution height. It queries `niri msg outputs` and emits JSON with a Niri config block for each display.

### Build

```bash
cd ~/Github/nightforge/niri-modifications
go build -o outputs/niri-outputs outputs/main.go
```

### Run

```bash
./outputs/niri-outputs
```

Output is JSON — each entry includes a `niri_config` field with a ready-to-paste KDL output block. After running, copy the `niri_config` block into `~/.config/niri/local.kdl` (or the appropriate config include) to apply the detected display configuration.

### Scaling Recommendations

| Resolution Height | Recommended Scale |
|-------------------|-------------------|
| ≥ 4320 (8K)       | 2.0               |
| ≥ 2160 (4K)       | 1.5               |
| ≥ 1440 (QHD)      | 1.25              |
| < 1440 (FHD)      | 1.0               |

## scripts/

### keybinds-parser.sh

Parses `~/.config/niri/includes/keybinds.kdl` and emits JSON describing every keybinding — key combo, action, section, and human-readable description. Section headers are extracted from `// === Section Name ===` comments in the KDL file.

Used by the operator dashboard to display active keybinds.

### startups-parser.sh

Parses startup entries from three sources:

1. **Niri config** — `spawn-at-startup` directives in `~/.config/niri/config.kdl`
2. **systemd user services** — enabled services from `systemctl --user list-unit-files`
3. **XDG autostart** — `.desktop` files in `~/.config/autostart/`

Emits JSON with name, command, and source for each entry. Used by the operator dashboard to show what starts at session launch.

### lock-screen.sh

Launches a screen locker (Niri has no built-in lock). Tries in order:

1. **gtklock** — best theming support; uses `dotfiles/gtklock/style.css` and a random wallpaper from `~/Pictures/wallpapers/`
2. **swaylock** — fallback with Catppuccin Mocha colors
3. **No lock tool** — prints warning and exits

Bound to `Mod+Alt+L` in `keybinds.kdl`:

```kdl
Mod+Alt+L { spawn "sh" "-c" "~/.config/quickshell/scripts/lock-screen.sh"; }
```

> **Note:** The lock-screen script is also copied to `~/.config/quickshell/scripts/lock-screen.sh` during deployment.

### rotate-wallpaper.sh

Picks a random wallpaper from `~/Pictures/Wallpapers/` (or `~/Pictures/wallpapers/`), sets it via `swww`, and triggers `matugen` to regenerate the color palette from the new wallpaper.

Used as a timed rotation script or triggered manually.

## Integration

These tools fit into the NightForge v3 deploy pipeline:

| Tool | Integration Point |
|------|-------------------|
| `outputs/niri-outputs` | Run during initial setup to auto-detect display configuration and generate `local.kdl` |
| `scripts/keybinds-parser.sh` | Consumed by the operator dashboard (Quickshell) to display active keybindings |
| `scripts/startups-parser.sh` | Consumed by the operator dashboard to show startup services |
| `scripts/lock-screen.sh` | Bound to `Mod+Alt+L` in `keybinds.kdl` (also deployed to `~/.config/quickshell/scripts/`) |
| `scripts/rotate-wallpaper.sh` | Called by wallpaper rotation timer or manual trigger; feeds matugen color pipeline |

See `docs/NIRI-MIGRATION.md` for the full migration walkthrough and `docs/KEYBINDS.md` for the human-readable keybind cheatsheet.

## Quick Start

```bash
# Build the display detector
cd ~/Github/nightforge/niri-modifications
go build -o outputs/niri-outputs outputs/main.go

# Detect displays and generate local.kdl
./outputs/niri-outputs

# Parse keybinds for the dashboard
./scripts/keybinds-parser.sh

# Parse startup configs for the dashboard
./scripts/startups-parser.sh

# Rotate wallpaper
./scripts/rotate-wallpaper.sh

# Lock screen
./scripts/lock-screen.sh
```