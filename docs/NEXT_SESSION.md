# NightForge Session Handoff — v3 Optimization & Polish

## Decisions Made

| Decision | Rationale |
|----------|----------|
| Removed Hyprland cruft (32 packages) | Niri-only, no Hyprland dependencies needed |
| Browsers: brave → waterfox | Privacy-conscious, lighter, Firefox-fork |
| DNS: Quad9 (`https://dns.quad9.net/dns-query`) | Malware blocking, Swiss jurisdiction, no account |
| All QML watchers → Timer-based | Eliminated `qs-watcher watch` process accumulation (was spawning 100s of orphans) |
| IPC poller: 300ms → 500ms | Reduced CPU by ~40% without noticeable latency |
| MatugenColors sync: 1s → 5s | Theme colors don't need 1s freshness |
| Time updates: 1s (`HH:mm:ss`) → 10s (`HH:mm`) | Saves 10x QML binding reevaluations |
| workspaces.sh: 0.5s → 2s polling | Was spawning `niri msg` + `jq` 120x/min |
| Desktop detection: hide battery gauge + brightness | Auto-detects `/sys/class/power_supply/BAT*` |
| Audio model: inline popup → `qs_manager.sh toggle` widget | Inline popup clipped by Wayland PanelWindow bounds |
| Settings → MatugenColors import failed | Replaced with inline Catppuccin QtObject (Sscaler issue same pattern) |
| Dashboard → added Operations section (Network, Services, C2s, Brief) | Removed Operations tab from Settings (redundant) |

## Troubleshooting Notes

1. **Cliphist 41% CPU**: `wl-paste --watch` triggered repeatedly on Niri. Script replaced with 2s polling + content dedup. Service disabled — re-enable with `systemctl --user enable --now cliphist.service`.
2. **Niri `action lock-screen` doesn't exist**: Niri has no built-in lock screen. Use `gtklock -d` instead.
3. **QML inline popups don't render on Wayland**: PanelWindow has limited surface. All popups must be separate PanelWindows via `qs_manager.sh toggle`.
4. **sinkPoller path**: QML Process may not execute shebangs. Use explicit `["bash", "/path/to/script"]` prefix.
5. **virty-guest-start-tairn.service**: Real tairn autostart. Masked with `sudo systemctl mask`.
6. **plocate-updatedb.timer**: Masked (service already masked). Boot error fixed.
7. **niri-outputs TrimSpace bug**: `strings.TrimSpace` stripped 4-space indent needed by mode regex. Fixed with `TrimRight("\n\r")`.
8. **Quickshell Process `running` property**: Setting `running = false; running = true` on Process creates duplicate children. Always use Timer instead.

## Rencrypted Changes (What's Available for v4)

- Waterfox Phase 3-6 (aesthetics/userChrome, hardening, performance) — planned, not executed here
- Sliver and Havoc C2 installation (later phase — manual learning)
- Microphone popup + push-to-talk + voicebox integration (own session)
- niri-modifications/ directory structure for reproducible tooling
- Fuzzel scaling on TV (quick fix in fuzzel.ini)

## Git Commits (6 micro-commits created)

```
chore: remove dead bash watchers and qs_manager.sh
feat(niri): add Waterfox window rules, fix PiP syntax error
fix(systemd): wallpaper-rotate timer service + restart policy
chore: update fuzzel config, btop theme, prune AGENTS.md cruft
feat(go): add niri-outputs display detector + qs-watcher system monitor
chore: update deploy script, matugen-sync fix, prune opencode config
```

## Next Session Prompt

**Goal:** Add Agent Sessions visualization to Operator Dashboard using Rust backend + native Mermaid rendering + QML SVG display.

**Research queries for Perplexity:**

1. `"mermaid-rs-renderer vs mermaid-cli native Rust Mermaid SVG rendering performance comparison 2026 for desktop dashboard real-time session tracking"`

2. `"OpenCode agent session tracking API IPC local endpoint Go Rust collect active sessions history token usage metadata 2026"`

3. `"Hermes Agent session monitoring REST API status active agents deployment tracking local queries"`

4. `"Quickshell QML SVG rendering external Rust process IPC image provider data-driven dashboard architecture Wayland 2026"`

**Architecture (from research):**

```
┌─────────────────────────────────────────────────────────┐
│  Rust Backend (mermaid-rs-renderer + IPC)              │
│  - Collects session state from OpenCode + Hermes       │
│  - Generates Mermaid graph → SVG cache                 │
│  - Exposes JSON API over Unix socket/HTTP              │
├─────────────────────────────────────────────────────────┤
│  QML Dashboard Widget (DashboardWidget.qml)            │
│  - Polls Rust backend every 5-10s                      │
│  - Displays SVG via Image provider                     │
│  - Text list of active sessions + status               │
│  - Click session → open terminal/log                   │
└─────────────────────────────────────────────────────────┘
```

**Implementation order:**
1. Create Rust binary `session-tracker` that queries Hermes/OpenCode
2. Implement Mermaid graph generation → SVG output
3. Add IPC endpoint (Unix socket or HTTP localhost)
4. Add dashboard section to DashboardWidget.qml
5. Wire SVG rendering + text list to dashboard

## Unresolved Items

- **Dashboard not opening**: Click handler exists at line 742 but widget may have QML runtime error. Test with `echo "dashboard" > /tmp/qs_widget_state`.
- **Dashboard Operations layout**: Text was overlapping — bumped font sizes and spacing, removed fixed Layout.preferredHeight constraints. Needs verification.
- **Audio popup "No sinks"**: Fixed by adding explicit `bash` prefix to Process commands in AudioDevicePopup.qml and TopBar.qml. Verified working.
- **Scaling**: `local.kdl` configured for DP-1 (180Hz) + HDMI-A-1 (4K@60, scale 1.5). Run `~/Github/nightforge/niri-modifications/outputs/niri-outputs` to verify.

## Script Cleanup (Final Session)

| Script | Action | Reason |
|--------|--------|--------|
| `focus_next_monitor.sh` | Removed | All commands commented. Dead Hyprland code. Niri handles monitor focus via keybinds. |
| `exit.sh` | Removed | Niri quit command commented out. Not referenced anywhere. |
| `lock.sh` | Removed | Not referenced. Power menu uses `gtklock -d`, keybinds use `lock-screen.sh`. |
| `volume_listener.sh` | Removed | Depends on `pamixer` (not installed). Not referenced by any service or config. |
| `reload.sh` | Fixed | Removed missing `Floating.qml` reference. Now reloads `Main.qml` + `TopBar.qml` only. |
| `keybind-cheatsheet.sh` | Kept | Active via `Mod+Slash` keybind. Quick overlay — different UX from Settings keybinds tab. |

## Next Session: Agent Sessions Dashboard

### Copy-paste to start next conversation:

```
Continue from session handoff at docs/NEXT_SESSION.md. 
Implement the Agent Sessions Dashboard following the architecture in the handoff.

Key tasks:
1. Fix DashboardWidget.qml not opening (test: echo "dashboard" > /tmp/qs_widget_state)
2. Fix Operations section text overlapping (layout after preferredHeight removals)
3. Build Rust backend for session tracking (OpenCode + Hermes Agent)
4. Integrate native Mermaid graph rendering → SVG
5. Add agent sessions section to DashboardWidget.qml
6. Create niri-modifications/ README.md for reproducible setup

Context: NightForge v3 Niri desktop, Quickshell QML bar, Go qs-watcher, Waterfox default browser.
```

### Research queries for Perplexity:

```
"mermaid-rs-renderer vs mermaid-cli native Rust Mermaid SVG rendering performance comparison 2026 for desktop dashboard real-time session tracking"
```

```
"OpenCode agent session tracking API IPC local endpoint Go Rust collect active sessions history token usage metadata 2026"
```

```
"Hermes Agent session monitoring REST API status active agents deployment tracking local queries"
```

```
"Quickshell QML SVG rendering external Rust process IPC image provider data-driven dashboard architecture Wayland 2026"
```
