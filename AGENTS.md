# nightforge — Agent Rules

## Purpose

Operator workstation repository for CR1MS0N-Operator. Omarchy-based (opinionated
Arch Linux) desktop environment (Hyprland/Omarchy shell/Omarchy theming dotfiles), rootless
Podman container profiles, and the TETHER harness control plan (Go, `127.0.0.1:9191`).

## Language policy (operator rule, 2026-11-01, decision #289)

Only Rust, Go and C/C++ ship first-party software:

- **Big projects** — services, long-lived programs, substantial internal logic → **Rust**, as much as possible.
- **Tools and scripts** — first-party CLIs, gates, helpers → **Go**, standard library only.
- **C/C++** — only when a measurement shows a drastic difference; never a default, never a preference.

**Browser UI is the one scoped exception (decision #290).** TypeScript is permitted for code that runs
in a browser when an application genuinely needs a framework; services and APIs stay Rust/Go, and a
TypeScript/Node backend is a violation, not an application of the exception. Static/content sites are
content, not software.

**This repo's only software is the TETHER harness — a long-lived service, so the big-project (Rust) tier; the existing Go predates this rule.** Dotfiles and shell here are config, not software.

Authority: decision #289 and `~/Documents/ai-lab-vault/AGENTS.md` § "Language policy". Open point: existing shell glue is thin operator glue, not software, and stays until touched.

## Agent Architecture (current)

| Role | Scope |
|------|-------|
| **Hermes** | Primary orchestrator — planning, proposals, decisions, coordination |
| **pi** | Brain — planning, proposals, decisions, roadmap |
| **OMP** | Executor — implements approved plans, code, docs, verification |
| **zero** | Offsec / cron — quick fixes, scheduled maintenance tasks |

Model/provider truth is the **live routing table** served by the harness at
`GET http://127.0.0.1:9191/api/v1/routes` (source:
`internal/handler/routes.go`). Do not hardcode model claims in docs; the
served table is authoritative.

## Session Strategy

- `--fork` — branch session for exploratory work
- `--continue` — resume prior session
- Use `docs/solutions/` and `docs/plans/` for cross-session context transfer

## GSD Workflow

Execute in order, adapted to this repo:

1. `go vet ./...`
2. `go build ./cmd/harnessd/`
3. `bash -n` on any changed `.sh` (CI-enforced; `shellcheck` optional locally)
4. CUE migration work: `go build ./cmd/cue-validate/` + validate against
   `cue/` schemas (see `docs/CUE-MIGRATION.md`)

## TETHER Operations

```bash
go build ./cmd/harnessd/
./harnessd                       # 127.0.0.1:9191
curl -s http://127.0.0.1:9191/api/v1/health
systemctl --user status harnessd # deployed service
```

Pipelines live in `scripts/harness/`; telemetry in `data/`; plans/solutions
in `docs/plans/` and `docs/solutions/`.

## Observability Stack

`10-layer-stack/observability-stack/` (Docker Compose: OTel, Prometheus,
Grafana, Langfuse, node-exporter) — L2/L9 substrate for AgentGateway traces
and host metrics. **Not started automatically.** Operator starts it after
populating `.env`; ports 31744–31750, all loopback-bound. See
`10-layer-stack/README.md`.

## Constraints

- **Never** modify or stage: `data/` (telemetry), `dotfiles/omarchy/`
  (deploy state), `docs/plans/`, `harnessd.bak`
- **Never** push without explicit approval
- Stage only files you personally changed; prefer micro-commits with
  meaningful messages
- Do not modify application behavior or source logic in docs-only passes
- If a cleanup would risk deleting user work, stop and report it

## Documentation

- `README.md` — overview, quick start, TETHER API
- `ARCHITECTURE.md` — TETHER + desktop shell design
- `CONTRIBUTING.md` — contribution workflow
- `docs/INSTALL.md`, `docs/TROUBLESHOOTING.md` (top level), `docs/DECISIONS.md`

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is **not currently indexed** by GitNexus: `gitnexus list_repos`
shows only the `euphrates` repo in the registry. To re-enable code
intelligence here, run `npx gitnexus analyze` in this repo and register it.
Until then, prefer plain `grep`/`read` navigation.

If a GitNexus tool warns the index is stale, run `npx gitnexus analyze` first.
<!-- gitnexus:end -->

## Reference

- CR1MS0N context: `~/Documents/cr1ms0n-ops/CLAUDE.md`
