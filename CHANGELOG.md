# NightForge — Changelog

All notable changes are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/); newest first.

## 2026-10-19 — Observability Stack Honesty Pass (bead `nightforge-aaj`)

Operator decision: **drop the competing Langfuse.** The live instance is the
canonical one on `127.0.0.1:50598` (docker project `langfuse`, outside this
repository). The duplicate in this repo had never run.

### Removed
- **Duplicate Langfuse** from `10-layer-stack/observability-stack/docker-compose.yml`:
  `langfuse-web`, `langfuse-worker`, `postgres`, `clickhouse`, `minio`,
  `redis`, their five named volumes, and every env var only they used
  (`POSTGRES_PASSWORD`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_USER`,
  `CLICKHOUSE_MIGRATION_URL`, `CLICKHOUSE_URL`, `CLICKHOUSE_CLUSTER_ENABLED`,
  `REDIS_AUTH`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `SALT`,
  `ENCRYPTION_KEY`, `NEXTAUTH_URL`, `NEXTAUTH_SECRET`, `DATABASE_URL`,
  `TELEMETRY_ENABLED`, `LANGFUSE_*` init vars).
- **OTel Collector** (`:31744`) and `otel-collector.yml` — its only exporter
  destination was the duplicate Langfuse, and no producer targets `:31744`.
  The canonical path is OMP → `:50598` direct
  (`cr1ms0n-otel-env.service`) and dsh → `:14318` bridge → `:50598`.
- **`grafana-dashboard.json`** (four-agent dashboard) — every panel queried a
  metric nothing emits (`harness_*`, `agentgateway_*`, `DCGM_FI_DEV_GPU_UTIL`).
  Replaced by `nightforge-metrics.json`, node-exporter series only.

### Fixed
- **Scrape targets:** removed `agentgateway` → `127.0.0.1:31745` (AgentGateway
  purged 2026-08-16; nothing listens there) and `harnessd` → `127.0.0.1:9191`
  (the served router registers no `/metrics`; `GET /metrics` → 404).
  `prometheus.yml` now has one target, `node` → `127.0.0.1:31750`, which works.
- **Secrets fail loudly:** `${VAR:-REPLACE_*}` defaults are gone. The one
  remaining secret, `GRAFANA_ADMIN_PASSWORD`, is `${GRAFANA_ADMIN_PASSWORD:?...}`,
  so compose refuses to parse the file when it is unset or empty. A missing
  `.env` is an error, not a placeholder password. `.env.example` rewritten
  with non-secret placeholders only.
- **README startup path:** `~/Github/nightforge` → `~/Projects/nightforge`.
  `~/Github` does not exist on this workstation; the old path resolved to
  nothing. Stated plainly in the stack README and
  `10-layer-stack/observability-stack/TROUBLESHOOTING.md`.
- **Collector data path:** `internal/collector/history.go` wrote health
  snapshots to `$HOME/Github/nightforge/data/history` — a path that does not
  exist, so snapshots went nowhere. Now honours `NIGHTFORGE_DATA_DIR` and
  falls back to `$HOME/nightforge/data`, matching `scripts/harness/`.
- **Langfuse discovery:** `internal/collector/discovery.go` probed `:31744`
  (the retired collector) to decide whether Langfuse was up. It now probes the
  canonical `:50598`, and parses the host/port from the configured endpoint
  instead of hardcoding the address. `internal/config` default updated too.
- **Root README API table** listed routes the daemon does not serve
  (`/api/v1/cost`, `/api/v1/routes`, `/api/v1/sessions`, `/api/v1/snapshots`,
  `/metrics`) and pointed at `internal/server`, a package no binary imports.
  Corrected to the routes `internal/api` actually registers, verified by
  exercising the router.

### Added
- `10-layer-stack/observability-stack/PORT-REGISTRY-PROPOSAL.md` — the exact
  vault port-registry rows this stack needs (`31745`/`31746`/`31750` to add,
  `31744`/`31747` as decommissioned, and why `9191` is not a stack port).
  The registry itself is vault-owned and was not modified from this repo.

### Known gap (not fixed here — needs a decision)
- The TETHER control plane still serves **no** `/metrics` endpoint. Adding it
  to `internal/api` is a code change beyond this pass's file-and-config
  scope; the Prometheus target was removed rather than left permanently down.

## 2026-08-01 — Security Remediation & Stale-Directory Audit

### Security
- **Sanitized session handoffs**: `docs/archive/SESSION_HANDOFF.md` and
  `docs/archive/NEXT_SESSION.md` converted to redacted templates — no
  operational data (processes, keybinds, paths); handoff policy documented
- **Removed embedded forgejo token** from the local git remote URL
  (`.git/config`); rotation required — see `SECURITY.md` → Known Token Exposure
- **SECURITY.md**: documented PUBLIC repo status, handoff policy, token
  exposure, and OPSEC documentation guidelines
- **.gitignore**: added credential-in-remote policy note

### Docs
- **`docs/CLEANUP-CANDIDATES.md`** (new): consolidated P1 stale-dir audit and
  P2 remaining candidates with evidence and recommended actions

### Audit (no deletions performed)
- **Empty/abandoned** (untracked): `10-Stack/architecture/`,
  `internal/cache/`, `data/stream_store/`, `80-Operations/infra/langfuse/`,
  `80-Operations/scripts/memory/`
- **Legacy**: `data/state_store.db/` (nightforged-era tracked binary),
  `modules/nightowl/` (optional integration, engagement dir already removed)
- **Documented**: routes.go Hermes BRAIN entry vs deprecated Hermes; go.mod
  module path mismatch; QML source drift; missing LICENSE; GitNexus index


## 2026-07-28 — Harness Dashboard Migration (10-Layer)

### Added
- **harnessd Go backend** on `127.0.0.1:9191` — stdlib-only module
  (`cmd/harnessd/` + `internal/{server,handler,collector}`), frontend embedded
  via `//go:embed`
- **6 API endpoints**: `/api/v1/{health,layers,sessions,snapshots,routes,cost}`
- **Single-file frontend** (`cmd/harnessd/frontend/index.html`) — Matugen dark
  theme, 6 tabs (L4 Health, L5 Proposals, L6 Gates, L7 Snapshots, L8 Routes,
  Cost/Tokens), 30s auto-refresh
- **Health collector**: 5-minute ticker, JSONL history in `data/history/`,
  daily min/max/avg summary
- **Token tracking**: `data/tokens/current.json`, Cost/Tokens tab, 30-minute
  cron (`scripts/harness/token-tracker.sh`)
- **Pi session parser**: cost data from OMP/Pi session JSONL
  (`scripts/harness/pi-session-parser.sh`)
- **L4/L5/L6 data pipelines** with detail views (failure-miner,
  proposal-engine, gate-check)
- **L7 snapshot pipeline** with history views (snapshot-config, rollback)
- `~/.config/systemd/user/harnessd.service` (systemd user) replaces `nightforged.service`

### Removed
- Dead dashboard components: `nightforged`, `session-tracker`, `harness`,
  `dashboard-ctl` (commit `21358e9`)
- Stale agent dirs `.claude/`, `.aider*`, `.dmux/`, `.codegraph/`,
  `.gitnexus/`; `.gitignore` updated to prevent reintroduction

## 2026-06-28 — Shell Bar Cleanup

- Purged old quickshell `Bar.qml`; archived `TopBar-legacy.qml`; live bar
  symlinked to dotfiles; `compositor.kdl` changes committed (quickshell
  overlay fixes)

## 2026-06-21 — Deep Audit & P0 Fixes

### Code Quality
- **Rebrand**: Replaced all "Azrael Security" → "CR1MS0N-Operator" and "ForeverLX" URLs → "CR1MS0N-Operator" across README, AGENTS.md, AGENTS.pi.md, go.mod, dotfiles, .claude hooks
- **shellcheck**: Fixed SC2155 (declare+assign), SC2188 (redirect), SC2086 (quoting), SC2126 (grep -c), SC2162 (read -r), SC2046 (quoting) across 8 scripts
- **Removed dead code**: mermaid.rs + mermaid-rs-renderer dep from session-tracker
- **Docker→Podman**: Fixed container.go to use `podman` not `docker`; updated service.go monitored services
- **Created docs/INSTALL.md**: Resolved broken link from README Quick Start
- **Cleaned .gitignore**: Removed stale nightforge-tui/target/ entry

### Go Hardening (dashboard-ctl)
- Added `--json` flag for machine-readable output
- Improved error handling: list functions return errors instead of empty slices
- Made TLS InsecureSkipVerify conditional (enabled for localhost only)
- Added HTTP timeout safety in c2.go
- Container/service error propagation on command failure

### Rust Hardening (session-tracker)
- Added `--output` CLI flag and `SESSION_TRACKER_OUTPUT` env var
- Replaced all `expect()`/`unwrap()` with proper error propagation
- Fixed clippy warnings (`-D warnings` clean)

### Repository
- Set GitHub topics (arch-linux, niri, red-team, offensive-security, etc.)

## 2026-05-04 — Full Stack Rebuild

### Architecture Change
- **Single overlay PanelWindow** with StackView for all widgets (replaced multi-PanelWindow approach)
- **Two-process Quickshell**: `shell.qml` (overlay) + `TopBar.qml` (bar) — launched separately
- **IPC**: `/tmp/qs_widget_state` file-based with 300ms polling (replaced `/tmp/quickshell-toggle`)

### Visual Layer (Port from ilyamiro)
- **TopBar.qml**: Replaced from ilyamiro (1567 lines) — per-screen Variants, inline media, workspace pills with mauve highlight, status icons, glass background, startup cascade animations
- **Center pill**: Clock + date + compact CPU/RAM display → click opens `ghostty -e btop`
- **Status pills**: wifi, bt, volume (click=mute, scroll=volume), battery, keyboard layout
- **Weather replaced**: With live system info (CPU + RAM, 5s polling)

### Widget System
- **Music widget**: ilyamiro MusicPopup with album art, progress bar, controls, cava FIFO equalizer
- **Network widget**: Hub-and-bubble style with WiFi/BT tabs
- **Settings (ControlCenter)**: Volume/brightness sliders, system toggles, podman container list
- **Wallpaper picker**: Grid of wallpapers with thumbnails, click applies via `awww`
- **Monitor widget**: Resolution grid, refresh rate slider
- **StatusMonitor**: 3 tabs — System/Containers/Sessions
- **Dashboard widget**: Calendar + clock + btop-style system info (created, not wired — click opens btop in terminal instead)

### Shell & Terminal Stack
| Tool | Before | After | Why |
|------|--------|-------|-----|
| **Zsh** | oh-my-zsh (slow) | Zinit (turbo) | 0.08s startup vs 100ms+ |
| **Starship** | None | Operator prompt | K8s/container/git modules, Catppuccin color |
| **Ghostty** | Basic | Keybind hierarchy, performance tuning | `renderer=opengl`, no conflict with tmux/Niri |
| **Tmux** | None | C-Space prefix, resurrect/continuum/fingers, wl-copy clipboard | Session persistence across reboots |

### Editor
- **Neovim**: Bare config → LazyVim starter + matugen theme + security plugins (toggleterm, telescope, lazygit, neo-tree, markdown-preview, supermaven)
- **Zed**: Recommended for future — hybrid approach (Neovim for dev, Zed for agent-assisted work)

### Firefox
- **user.js**: arkenfox v144 → Betterfox (less breakage for research workflows)
- **Wayland**: `MOZ_ENABLE_WAYLAND=1` wrapper script
- **Policies**: `/etc/firefox/policies.json` — force-installs uBlock Origin, Multi-Account Containers
- **MPRIS**: `media.hardwaremediakeys.enabled = true` (music widget shows Firefox/YouTube)
- **userChrome.css**: Compact dark UI, smaller tabs/url bar

### Niri Configuration
- **Window rules**: Enhanced for popups (Preferences/Settings/Save As), PiP (`max-width 400, max-height 300`), Discord, Quickshell
- **Output scaling**: DP-1 (1080p @ 1.0), HDMI-A-1 (4K @ 1.5) — already correct
- **Screensharing**: `xdg-desktop-portal-gnome` prioritized, dbus env vars
- **Border**: `width 0` with transparent colors (Niri's built-in focus indicator still shows — not configurable)
- **Keybinds**: Audio sink toggle (`Mod+A`), Escape closes widget, widget shortcuts updated

### Audio
- **PipeWire**: 1.6.4, low-latency config (quantum 512), WirePlumber policies
- **HDMI/Analog switching**: `audio-switch.sh toggle` script + `Mod+A` keybind
- **ALC897 codec**: Hardware jack detection issue — fixed via WirePlumber config + hdajackretask
- **MPRIS**: Firefox + MPD both registered with playerctl

### Clipboard
- **Daemon**: `cliphist` with `wl-paste --watch` loop (replaced non-working `cliphist watch`)
- **Picker**: `Mod+V` opens fuzzel with clipboard history

### Scripts
- **qs_manager.sh**: IPC router — writes colon-separated commands to `/tmp/qs_widget_state`
- **lock-screen.sh**: gtklock with wallpaper background + dark CSS overlay
- **audio-switch.sh**: Toggles between HDMI and Analog sinks, moves active streams
- **cliphist-daemon.sh**: `wl-paste --type text --watch cliphist store` loop
- **screenshot.sh**: grim + slurp + satty workflow
- **screen-record.sh**: wf-recorder toggle with notifications

### Theming (Matugen Pipeline)
- **Outputs**: `/tmp/qs_colors.json` (QML), niri `colors.kdl` (border), fuzzel `colors.ini`, ghostty config, Firefox `userChrome.css`, qt5ct
- **Trigger**: `matugen-sync.sh` runs on wallpaper change → regenerates all theme files
- **Color transform**: Material Design → Catppuccin key mapping

### Key Decisions
| Decision | Rationale |
|----------|-----------|
| **Betterfox** over arkenfox | Less site breakage for OSINT/research workflows |
| **Zinit** over antidote/OMZ | Fastest startup, best async/turbo plugin loading |
| **LazyVim** over NvChad/AstroNvim | Most modular for custom theming (matugen integration) |
| **Cliphist** over greenclip/copyq | Wayland-native, works with wl-clipboard |
| **Extra/cava** over AUR forks | Official repo, reproducible, FIFO pipe for music widget |
| **Wayland wrapper** for Firefox | Ensures native Wayland rendering with proper env vars |
| **Single Firefox profile** with containers | Multi-profile deferred — containers provide isolation without overhead |
| **Ghostty** over Warp | Lighter resource usage, no redundant AI layer (already have OpenCode) |
| **hybrid Neovim+Zed** | Neovim for daily dev/scripting, Zed for agent-assisted codebase nav |

### Troubleshooting Log
| Issue | Root Cause | Resolution |
|-------|-----------|------------|
| **File descriptor leak (Too many open files)** | MatugenColors polled every 1s reading non-existent path; Scaler watcher polled on non-existent settings.json | Fixed paths, increased intervals, created `/tmp/qs_colors.json` |
| **Widgets open/close immediately** | ipcWatcher (inotifywait) + ipcPoller (timer) both processed same command — double toggle | Disabled ipcWatcher, kept ipcPoller only |
| **No audio from speakers** | ALC897 codec jack detection → Headphone channel at 0%/muted | WirePlumber config force analog profile + `hdajackretask` |
| **Blue tint on ghostty** | Client-side decoration focus indicator from GTK theme | `window-decoration = false` + `prefer-no-csd` |
| **GPU: OpenCL error (IgProf)** | Nvidia OpenCL ICD not installed | Install `ocl-icd` or ignore (non-functional) |
| **CPU 0% in system info** | Wrong `top` output format (Cpu(s) vs %Cpu) | Fixed awk to use `%Cpu` pattern + column 8 (idle) |
| **Wallpaper picker empty grid** | `Qt.labs.folderlistmodel` blocked by Quickshell; thumbnail scanner used `file://` path with `ls` | Replaced with Process-based scanner; fixed path to use raw filesystem paths |
| **Search tool crashes quickshell** | qs_manager.sh wrote space-separated args; processIpc expected colon-separated | Changed `$TARGET $SUBTARGET` → `$TARGET:$SUBTARGET` |
| **TopBar syntax error (extra braces)** | Multiple sed edits + block replacements caused brace mismatch | Removed 1 extra `}` at EOF |
| **Center layout broken** | MouseArea missing closing `}` — rightContent became child of MouseArea | Added missing `}` |
| **Lock screen solid red** | CSS `background-image: none` overrode `--background` flag | Removed `background-image: none`, added `background-size: cover` |

### Remaining Issues
1. **Blue window border** — Niri's built-in focus indicator; not configurable via `border` setting
2. **Help menu content** — GuidePopup.qml needs full rewrite for NightForge content
3. **Network hub-and-bubble** — Improve visual layout
4. **Monitor widget resolution switching** — Niri mode-setting is limited
5. **Dashboard widget** — Currently unwired; click opens ghostty+btop instead
6. **Zed install + config** — `sudo pacman -S zed`, `vim_mode: true`
7. **Screenshots/screen recordings** — For GitHub repo documentation
8. **Clean up scripts** — Audit `scripts/` for dead code, wrong paths, ilyamiro remnants
9. **Wallpaper directories** — User mentioned duplicates (lowercase vs capital W)
