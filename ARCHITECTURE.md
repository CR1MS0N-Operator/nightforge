# NightForge Architecture

Active subsystems:

1. **TETHER Harness Control Plan** — Go monitoring daemon on `127.0.0.1:9191`
2. **Observability Stack** — Docker Compose (OTel/Prometheus/Grafana/Langfuse)
3. **CUE Config Migration** — CUE schemas + Go toolchain for Hyprland config
4. **Desktop Shell** — Hyprland compositor + Omarchy shell + Omarchy theming

The Go module is `github.com/CR1MS0N-Operator/nightforge` (`go 1.26.5`), with
`go-chi/chi/v5` as the only external dependency (dashboard API router).

---

## 1. TETHER Harness Control Plan

### Overview

A single-binary monitoring dashboard: 5-minute health collection, layered
pipeline state (proposals/gates/failures/snapshots/tokens/cost), and a
single-file HTML frontend embedded via `//go:embed`. No DB, no npm, no
external deps. Runs as a systemd user service
(`~/.config/systemd/user/harnessd.service`, deployed outside the repo).

### Components

| Component | Purpose | Location |
|-----------|---------|----------|
| Entry point | Embed frontend, start collector, serve | `cmd/harnessd/main.go` |
| Router | API routes + static files + CORS/logging middleware | `internal/server/server.go` |
| Handlers | One per endpoint, JSON responses | `internal/handler/` |
| Collector | 5-min health ticker, JSONL persistence | `internal/collector/health.go` |
| Frontend | Single `index.html`, inline CSS/JS, Omarchy-dark | `cmd/harnessd/frontend/` |

### API

| Endpoint | Handler | Source data |
|----------|---------|-------------|
| `GET /api/v1/health` | `health.go` | In-memory history + `data/history/*.jsonl` |
| `GET /api/v1/layers` | `layers.go` | Static 10-layer table + `data/{proposals,gates,failures}/*.json` |
| `GET /api/v1/sessions` | `sessions.go` | Pi/OMP/Hermes session directories |
| `GET /api/v1/snapshots` | `snapshots.go` | `data/snapshots/` |
| `GET /api/v1/routes` | `routes.go` | Static routing table (see below) |
| `GET /api/v1/cost` | `cost.go` | `data/tokens/current.json` (404 + hint until `token-tracker.sh` runs) |

### Data Flow

```
Collector (5-min ticker)
    │  reads /proc, /sys, nvidia-smi
    ▼
data/history/health-YYYY-MM-DD.jsonl   ← append-only snapshots
    ▲
    │  loaded at startup (loadHistory)
    │
handlers ── JSON ──▶ frontend (6 tabs, 30s health auto-refresh)
    ▲
scripts/harness/*.sh  (failure-miner, proposal-engine, gate-check,
    │                   snapshot-config/rollback, token-tracker,
    │                   pi-session-parser)
    ▼
data/{failures,gates,proposals,snapshots,tokens,cost}/
```

### Observability Stack

`10-layer-stack/observability-stack/` (Docker Compose, operator-started)
collects **host metrics** for L4 health:

| Service | Port (loopback) | Role |
|---------|-----------------|------|
| Prometheus | 31745 (`127.0.0.2`) | Scrapes node-exporter |
| Grafana | 31746 | Host-metrics dashboard |
| node-exporter | 31750 | Host CPU/memory/disk/load |

Trace and LLM observability live in the **canonical Langfuse** outside this
repository, on `127.0.0.1:50598` (docker project `langfuse`, compose at
`~/Documents/ai-lab-vault/20-Tools/agentsview-langfuse-setup/langfuse/`).
The duplicate Langfuse and the OTel Collector that fed it were retired on
2026-10-19 (bead `nightforge-aaj`).

Ports and startup procedure: `10-layer-stack/README.md`,
`10-layer-stack/observability-stack/TROUBLESHOOTING.md`, and the port rows
proposed for the vault registry in
`10-layer-stack/observability-stack/PORT-REGISTRY-PROPOSAL.md`.

### CUE Config Migration

Hyprland config is migrating from hand-maintained Lua to CUE schemas
(`cue/nightforge.cue`, `cue/schema.cue`) with a Go toolchain:

```
cue/nightforge.cue ──▶ cmd/cue-to-kdl ──▶ ~/.config/hypr/hyprland.lua
       ▲
cmd/cue-validate / cmd/fidelity-check / cmd/hypr-staging-validate
```

`scripts/*.sh` launchers build the tools into `build/bin/` on demand. See
[docs/CUE-MIGRATION.md](docs/CUE-MIGRATION.md).

### Model Routing

The live routing table is served at `GET /api/v1/routes` from the static
slice in `internal/handler/routes.go` (currently 4 roles: Hermes BRAIN,
OMP EXECUTOR, Subagents, Pi/gnhf). It is the same table the L3/L8 layers
reference. Note: per current agent guidance in [AGENTS.md](AGENTS.md), Hermes
is deprecated and Pi is the planning role — the served table is a
reconciliation candidate, not something this doc changes.

### TETHER Architecture (Two-Stack)

TETHER defines two separate 10-layer stacks — a self-improving backend loop
and an operator-facing frontend. Phase 1 (L1+F1) is complete.

**Backend (self-improving loop):**

| Layer | Name | Status |
|-------|------|--------|
| L1 | Stable Substrate | **implemented** |
| L2 | Trace Log | design |
| L3 | External State | design |
| L4 | Failure Mining | design |
| L5 | Proposal Engine | design |
| L6 | Validation Gates | design |
| L7 | Versioning/Rollback | design |
| L8 | Routing & Variants | design |
| L9 | Benefit Measurement | design |
| L10 | Weight Update | design |

**Frontend (operator experience):**

| Layer | Name | Status |
|-------|------|--------|
| F1 | Stable Interface | **implemented** |
| F2 | Agent Visibility | design |
| F3 | Context Awareness | design |
| F4 | Behavioral Detection | design |
| F5 | Intervention Controls | design |
| F6 | Policy Enforcement | design |
| F7 | State Management | design |
| F8 | Task Routing | design |
| F9 | Performance Measurement | design |
| F10 | Learning Integration | design |

---

## 2. Desktop Shell

```mermaid
graph TB
    subgraph "Compositor Layer"
        HYPRLAND["Hyprland Wayland Compositor"]
    end

    subgraph "Omarchy Shell Layer"
        SHELL["shell.qml<br/>Entry Point (overlay)"]
        BAR["TopBar.qml<br/>Per-Screen Bar"]
        OVERLAY["Overlay PanelWindow<br/>StackView Widget System"]
        OSD["OSD.qml<br/>On-Screen Display"]

        subgraph "Services"
            OMARCHYCOLORS["OmarchyColors.qml<br/>Dynamic Palette"]
            MPDCLIENT["MpdClient.qml<br/>MPD State + Art"]
            VPN["VpnStatus.qml"]
            PODMAN["PodmanStatus.qml<br/>Container List"]
        end

        subgraph "Widgets (StackView)"
            W_CC["ControlCenterWidget"]
            W_MUSIC["MusicWidget"]
            W_NET["NetworkWidget"]
            W_WALL["WallpaperWidget"]
            W_STATUS["StatusMonitorWidget"]
            W_MON["MonitorWidget"]
        end

        subgraph "Components"
            GLASS["GlassPanel.qml"]
            BUTTON["BarButton.qml"]
            PILL["StatusPill.qml"]
            SLIDER["VolumeSlider.qml"]
            TOGGLE["ToggleButton.qml"]
            SCALER["Scaler.qml"]
        end
    end

    subgraph "IPC / Script Layer"
        QSM["qs_manager.sh<br/>Widget Toggle Router"]
        IPC["/tmp/qs_widget_state<br/>State File"]
        D_WORK["workspaces.sh<br/>Hyprland WS JSON"]
        D_MUSIC["music_info.sh<br/>Playerctl + Art Colors"]
    end

    subgraph "Theming Pipeline"
        OMARCHY_THEME["omarchy theme set<br/>Image → palette"]
        QT6CT["qt6ct / kvantum<br/>Qt App Theming"]
    end

    HYPRLAND -->|"spawn-at-startup"| SHELL
    HYPRLAND -->|"spawn-at-startup"| BAR
    OMARCHYCOLORS --> W_CC
    OMARCHYCOLORS --> BAR
    OMARCHYCOLORS --> W_MUSIC

    MPD --> MPDCLIENT
    MPDCLIENT --> BAR
    MPDCLIENT --> W_MUSIC

    D_WORK --> BAR
    QSM --> IPC
    IPC --> SHELL
    SHELL --> OVERLAY
    OVERLAY --> W_CC
    OVERLAY --> W_MUSIC
    OVERLAY --> W_NET
    OVERLAY --> W_WALL
    OVERLAY --> W_STATUS
    OVERLAY --> W_MON

    BAR -->|"dispatch()"| QSM
    KEYBINDS["bindings.lua"] -->|"Mod+Shift+S"| QSM
```

### Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Compositor | Hyprland (Wayland) | Window management, tiling, keybinds |
| Shell / Bar | Omarchy shell (Quickshell) | Widget overlay + per-screen bar |
| Theming | Omarchy theming | Dynamic color extraction from wallpaper |

### QML Source Layout

- **Canonical sources:** root `modules/` (incl. `Bar.qml`) and `services/` —
  imported by `dotfiles/quickshell/.config/quickshell/main.qml`
  (`import "../../../../services"`, `import "../../../../modules"`)
- **Deploy copies:** `dotfiles/quickshell/.config/quickshell/` — stowed to
  `~/.config/quickshell` by `scripts/apply-dotfiles.sh`; contains `shell.qml`,
  `TopBar-legacy.qml`, `main.qml`, `modules/`, `services/`, `components/`,
  `scripts/` (incl. `watchers/`)

### Services

| Service | Data | Updates |
|---------|------|---------|
| `OmarchyColors.qml` | Palette from Omarchy theme | File watcher |
| `MpdClient.qml` | Track, artist, album, art URL, elapsed/total, play state | `mpc` polling + `idle` event |
| `VpnStatus.qml` | WireGuard `wg show` connected state | 5s poll |
| `PodmanStatus.qml` | Running container count + names/status | 5s poll |
| `SysData.qml` | CPU/RAM/disk/temp via `/proc` | 3s poll |

### IPC

File-based router: `qs_manager.sh` writes commands to `/tmp/qs_widget_state`;
`shell.qml` polls the file (with `inotifywait` fallback) and pushes widgets
onto the overlay `StackView` (morph transitions).

### Hyprland Config

```
~/.config/hypr/
├── hyprland.lua       # Main config (loads Omarchy defaults, then user files)
├── bindings.lua       # Keybindings
├── monitors.lua       # Display configuration
├── input.lua          # Keyboard/mouse settings
├── looknfeel.lua      # Appearance (gaps, borders, animations)
├── autostart.lua      # Startup applications
├── hyprsunset.conf    # Night light / blue light filter
└── xdph.conf          # Screen sharing / desktop portal
```

### Theming Pipeline

```
Wallpaper change → omarchy theme set → Omarchy palette
    → OmarchyColors.qml (file watcher) → all QML components re-render
```

Templates live in `dotfiles/omarchy/.config/omarchy/themed/` (Ghostty,
GTK/Qt, Neovim, btop, Mako, Rofi, Starship, Quickshell).

---

## Dependencies

| Category | Packages |
|----------|----------|
| Compositor | `hyprland`, `omarchy` |
| Shell | `quickshell` (Qt6, QML) |
| Theming | `omarchy`, `qt6ct` |
| Media | `mpd`, `mpc`, `playerctl` |
| Network | `networkmanager`, `wireguard-tools`, `bluetoothctl` |
| Audio | `pipewire`, `wireplumber`, `pamixer` |
| Containers | `podman` |
| Utils | `jq`, `inotify-tools`, `socat` |
| Dashboard | Go 1.26+ (`go-chi/chi/v5` + stdlib) |
| Observability | Docker + Docker Compose (`10-layer-stack/observability-stack/`) |
| Config migration | CUE (`cue` CLI), Go tooling under `cmd/` |

---

## Known Issues

1. **Two QML source trees**: root `modules/`+`services/` and
   `dotfiles/quickshell/` copies have drifted (e.g. `modules/Bar.qml` differs
   from the dotfiles copy). Root is canonical per `main.qml` imports;
   reconciliation is a maintenance task, not a docs change.
2. **Workspace polling**: Hyprland event socket available; workspace state
   via `hyprctl` or event subscriptions.
3. **Routing table drift**: `internal/handler/routes.go` still lists a
   "Hermes BRAIN" role; current guidance marks Hermes deprecated (see
   [AGENTS.md](AGENTS.md)).

## Design Decisions

See [docs/DECISIONS.md](docs/DECISIONS.md) for the full rationale
(Hyprland over Niri, Omarchy shell over eww/AGS, Omarchy theming, Ghostty, Podman).
