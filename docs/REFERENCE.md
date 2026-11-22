# NightForge Technical Reference

[Back to the overview](../README.md) · [Installation](INSTALL.md) · [Architecture](../ARCHITECTURE.md)

Operational detail moved from the repository overview. The API section follows
`cmd/harnessd/main.go` and its served router, `internal/api/routes.go`.

## TETHER Harness Control Plan

The active monitoring system: a Go backend serving a single-file HTML frontend.
Build the Go binary; no database or separate frontend build is required. Depends only on
`go-chi/chi/v5` (router) plus the standard library. Replaces the former
`nightforged` daemon. See [configuration](../internal/config/config.go) for the
default address and JSON configuration file.

- **Daemon:** `cmd/harnessd/main.go` — loads config and starts the served router
- **Router:** `internal/api/routes.go` — `chi` router, API + SSE + static web
  UI, CORS / request-logging / recovery middleware
- **Handlers:** `internal/api/handlers.go` — one function per endpoint
- **Collector:** `internal/collector/` — health snapshots, ports, services,
  failures, proposals, gates, cost
- **Frontend:** `web/index.html` — inline CSS/JS, embedded via `embed.go`

### API

The routes below are the ones the served router (`internal/api`) actually
registers. The API has no `/api/v1/routes` endpoint; the similarly named
handler under `internal/handler/` belongs to a separate, unserved implementation.

| Endpoint | Returns |
|----------|---------|
| `GET /api/v1/health` | Latest health snapshot (parsed from `system-health.log`) |
| `GET /api/v1/services` | Discovered services (herdr, agents) |
| `GET /api/v1/ports` | Listening TCP ports with service names |
| `GET /api/v1/tasks` | Known agent tasks |
| `GET /api/v1/analysis` | Failure/proposal analysis |
| `GET /api/v1/logs` | Recent harness logs |
| `GET /api/v1/usage` | Token usage + cost |
| `GET /api/v1/layers` | 10-layer harness status |
| `GET /api/v1/layers/l4/failures` | Mined failure sessions |
| `GET /api/v1/layers/l5/proposals` | Proposal engine output |
| `GET /api/v1/layers/l6/gates` | Validation gate state |
| `GET /api/v1/layers/l7/snapshots` | Versioned snapshots |
| `GET /api/v1/alerts` | Harness alerts |
| `GET /api/v1/history` | Health snapshot history |
| `GET /api/v1/discovery` | Service discovery status |
| `GET /api/v1/config` | Effective control-plane config |
| `GET /api/v1/notifications` | Pending notifications |
| `POST /api/v1/notifications/read` | Mark notifications read |
| `DELETE /api/v1/notifications` | Clear notifications |
| `GET /api/v1/events` | SSE event stream |

> **No `/metrics` endpoint is served.** The `GET /metrics` handler in
> `internal/handler/metrics.go` belongs to `internal/server`, a package no
> binary imports — `cmd/harnessd` builds `internal/api.NewRouter()`. A
> Prometheus scrape of `:9191/metrics` therefore returns 404. That target was
> removed from `prometheus.yml` on 2026-10-19 (bead `nightforge-aaj`).
> Registering `/metrics` on the served router is a code change, still open.

### Data Store (`data/`)

| Path | Contents |
|------|----------|
| `data/history/` | Health snapshots, one JSONL per day |
| `data/snapshots/` | Versioned state snapshots (baselines) |
| `data/proposals/` | Proposal engine output (`proposals.json`) |
| `data/gates/` | Validation gate state (`gates.json`) |
| `data/failures/` | Failure-mining classification (`failures.json`) |
| `data/tokens/` | Token/cost tracking (`current.json`) |
| `data/cost/` | Per-session cost aggregates |

### Pipeline Scripts (`scripts/harness/`)

| Script | Role |
|--------|------|
| `pipeline-runner.sh` | Orchestrates the layer pipelines |
| `failure-miner.sh` | L4 — failure classification |
| `proposal-engine.sh` | L5 — proposal generation |
| `gate-check.sh` | L6 — validation gate rules (5 rules) |
| `snapshot-config.sh` / `rollback.sh` | L7 — versioning + rollback |
| `token-tracker.sh` | Token usage → `data/tokens/current.json` (30min cron) |
| `pi-session-parser.sh` | Cost data from OMP/Pi session JSONL |

### TETHER Architecture (Two-Stack)

TETHER defines two separate 10-layer stacks — a self-improving backend loop
and an operator-facing frontend. The tables below describe the two-stack design
milestones, not a coverage claim for the current scripts. See the [stack README](../10-layer-stack/README.md)
for implementation status and its layer-numbering notice.

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

Run with `systemctl --user status harnessd` on the workstation (TETHER daemon).
See [ARCHITECTURE.md](../ARCHITECTURE.md) for the full design and
[scripts/harness/](../scripts/harness/) for the pipeline implementation.

---

## Observability Stack

Host-metrics stack in
[`10-layer-stack/observability-stack/`](../10-layer-stack/observability-stack/):
Prometheus, Grafana and node-exporter. **Not started automatically** — the
operator creates `.env` and starts it (see the
[stack README](../10-layer-stack/README.md) for ports and the startup
procedure).

**Trace/LLM observability is not in this repository.** Langfuse is operated
separately, outside the repository. The duplicate Langfuse and the OTel
Collector that fed it were retired on
2026-10-19 — see
[`PORT-REGISTRY-PROPOSAL.md`](../10-layer-stack/observability-stack/PORT-REGISTRY-PROPOSAL.md).

---

## CUE Config Migration

NightForge configs are being migrated to [CUE](https://cuelang.org/) schemas
(`cue/nightforge.cue`, `cue/schema.cue`) with a Go toolchain under `cmd/`:

| Tool | Purpose |
|------|---------|
| `cmd/cue-to-kdl` | Export CUE config → staged Niri KDL |
| `cmd/cue-validate` | Validate CUE schemas + config |
| `cmd/fidelity-check` | Compare exported config against live state |
| `cmd/niri-backup` | Checksummed backup of tracked Niri config |
| `cmd/niri-staging-validate` | Validate staged config against CUE before apply |

Scripts in `scripts/` (`cue-to-kdl.sh`, `cue-validate.sh`, `fidelity-check.sh`,
`niri-staging-validate.sh`, `backup-niri-config.sh`) are thin launchers that
build into `build/bin/` on demand. See [docs/CUE-MIGRATION.md](CUE-MIGRATION.md).

---

## Desktop Stack

These operator desktop notes are retained from the previous overview, not a
record of a desktop deployed during this documentation pass. The repository
also includes a Niri configuration path; the CUE tools above target Niri KDL.

Wayland desktop built around Hyprland on Omarchy with Omarchy shell (Quickshell-based
bar + overlay). `~/.config/hypr/hyprland.lua` autostart: Omarchy shell, Podman
restart service, wallpaper rotation timer, MPD service.

| Component | Role |
|-----------|------|
| **Hyprland** | Wayland compositor (Omarchy default) |
| **Omarchy shell** | QML shell: overlay widgets (StackView) + per-screen bar |
| **Omarchy theming** | Material You color extraction, template-based re-theming |
| **Ghostty** | GPU terminal, SIGUSR1 config reload for theme switching |
| **Zsh + Starship** | Prompt + operator terminal framework (<100ms startup) |
| **Podman** | Rootless container profiles (toolbox, ad, re, web) |

### Design Decisions (condensed)

- **Hyprland over Niri** — Omarchy's default compositor, mature ecosystem,
  Lua config, auto-reload on save.
- **Omarchy shell over eww/AGS** — GPU-accelerated QML, watcher-based scripts
  (no polling loops), live Omarchy color sync.
- **Omarchy theming** — HCT tonal palette extraction, one wallpaper → configs
  for Ghostty/GTK/Qt/Neovim/btop/Mako/Rofi/Starship/Quickshell.
- **Rootless Podman over Docker** — no daemon, `--userns=keep-id`, local
  images only, export/import for air-gapped work.
- **Ghostty over Kitty/Alacritty/WezTerm** — multi-config dark/light maps to
  OPSEC theme switching; SIGUSR1 reload.

Full rationale in [docs/DECISIONS.md](DECISIONS.md).

### Container Profiles

Rootless Podman profiles, layered on a shared `toolbox` base:

| Profile | Purpose | Key Tooling |
|---------|---------|-------------|
| `toolbox` | Base runtime + Python | git, tmux, neovim, python, curl, jq, yq |
| `ad` | Active Directory engagement | Impacket, krb5, Samba, LDAP utils, RustHound-CE |
| `re` | Reverse engineering | radare2, GDB+gef, pwntools, ROPgadget, capstone, unicorn, Ghidra |
| `web` | Web recon | nmap, masscan, gobuster, httpx, nuclei, requests, go |

```bash
./modules/container/scripts/container.sh build-all   # build all profiles
./modules/container/scripts/container.sh build ad    # build one
./modules/container/scripts/container.sh run ad      # run (mounts engage/loot/notes/exploitdev/projects)
./modules/container/scripts/container.sh export ad   # air-gapped export .tar
```

> **Status:** Manifests and Containerfiles are version-controlled; treat
> profiles as in-progress and verify before use in engagements.

### Operator Terminal Framework

Contextual shell (dotfiles/operator-terminal): VPN/WireGuard status, active
engagement context, network awareness, podman status, git context, system
health, MITRE ATT&CK technique logging (`mitre log T1059.004 "…"`).

---

## Performance & Benchmarks

Historical measurements from the operator workstation (i3-10105F, GTX 1650),
not a performance guarantee or a benchmark from this documentation change:

| Metric | Value |
|--------|-------|
| Boot (systemd-analyze) | ~21.3s total (man-db 6.9s top offender) |
| Idle RAM | ~1.8 GB (Hyprland + Omarchy shell) |
| Terminal startup | ~87ms (operator framework) |
| Container build (toolbox) | ~3m45s first, ~30s cached |

Run `./scripts/benchmark/system-baseline.sh` for a full baseline
(`docs/benchmarks/` is gitignored — generated reports).

---

## Design Principles

1. **Reproducible by default.** Configs and manifests version-controlled; a
   fresh install should produce an identical environment.
2. **Minimal attack surface.** No Docker daemon, rootless containers, explicit
   mounts only.
3. **OPSEC-aware workflows.** Theme switching, VPN-aware terminal, engagement
   isolation, MITRE technique logging.
4. **Local-first.** All tooling runs locally; export/import for air-gapped ops.
5. **Maintainable over clever.** Boring tech (bash, Lua, QML, Go stdlib) with
   documented trade-offs.

---
