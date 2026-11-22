# Decisions

This file records project decisions to keep the workstation reproducible and avoid drift.

## Scope / Direction

- Base platform: Arch Linux (rolling) with a future path to archiso for a distro build.
- Focus: Red Team operator workflows (not a generic pentest distro).
- Reproducible by default: pacman packages + versionable config files.
- Local-first baseline. Cloud/AI is opt-in later (likely as a VM-focused profile).

## Profiles (locked)

1) local-only.profile
- Minimal baseline
- Local-first

2) solo-operator.profile
- Daily-driver profile
- Terminal: Ghostty
- Local-first

3) team-operator.profile
- Standardized, production-grade defaults
- Terminal: Kitty
- tmux included by default

We explicitly do NOT include WezTerm.

## Directory contract (locked)

Standard roots:
- ~/engage
- ~/loot
- ~/notes
- ~/exploitdev
- ~/projects

Engagement layout (per name):
- ~/engage/<name>
- ~/loot/<name>
- ~/notes/<name>
- ~/exploitdev/<name>

## tmux layouts (locked)

- Base operator layout:
  - scripts/tmux-layout.sh

- Per-engagement layout:
  - scripts/tmux-engage.sh <name>

- NightOwl layout (optional, docs-only integration):
  - modules/nightowl/scripts/nightowl-layout.sh

## NightOwl integration approach (locked)

- NightOwl is a separate repo and remains independent.
- NightForge provides:
  - deterministic session layouts
  - directory contract
  - docs for paths and evidence handling
- NightOwl code path:
  - ~/projects/nightowl
- NightOwl run artifacts:
  - ~/engage/nightowl/runs

## S226 Migration Decisions (Niri → Omarchy/Hyprland)

Decided 2026-09-03 during S226 planning session.

### Q1: Migrate to Waybar?
**Decision**: Migrate to Waybar. Use Omarchy plugin ecosystem where available.
**Rationale**: Omarchy provides its own bar system (`omarchy-bar`), but Waybar is more
customizable and aligns with the migration prompt. Omarchy's bar handles the basics;
Waybar gives full control over custom indicators (MPD, Podman, VPN, engagement context).

### Q2: CUE Schema Strategy
**Decision**: Evolutionary approach — rename `package niri` → `package hypr`, rename types,
keep same 3-section structure (spawns, binds, windowRules).
**Rationale**: Minimal disruption to Go tools. The 3-section structure maps well to
Hyprland config. Full redesign deferred to a future cleanup pass.

### Q3: Go Tools Necessity
**Decision**: Research and assess whether Go tools are even needed on Omarchy.
**Rationale**: Omarchy may provide built-in config management that makes custom CUE tools
redundant. Assess before porting 5 cmd/ directories.

### Q4: Theming Script
**Decision**: Full rewrite to `aether-sync.sh` (not relying on Omarchy built-in for all targets).
**Rationale**: Omarchy's built-in `omarchy theme set` may not cover all NightForge targets
(Firefox userChrome, Neovim colors, btop). Custom script gives full control over 15+ output targets.

### Q5: Screenshot Tools
**Decision**: Use Omarchy screenshot tools (`omarchy-capture-screenshot`, `omarchy-capture-screenshot-window`).
**Rationale**: Already installed and Omarchy-native. Replaces Niri's built-in screenshot actions
and the custom `screenshot.sh` script.

### Q6: Column-Specific Keybindings
**Decision**: Remove column-specific bindings entirely (no mapping).
**Rationale**: Hyprland has no column concept. `toggle-column-tabbed-display`,
`consume-or-expel-window-left/right`, `switch-preset-column-width` have zero equivalent.
Map `maximize-column` → `fullscreen` and `center-column` → `centerwindow` only.

## Container profiles (implemented)

A team-ready container environment is implemented: rootless Podman base
(`toolbox`) plus `ad`, `re`, and `web` profiles with directory-contract
mounts, versioned tags, and air-gapped export/import. See
[technical reference](REFERENCE.md#container-profiles).
