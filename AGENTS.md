# nightforge — Agent Rules

## Purpose

Operator workstation repository for CR1MS0N-Operator. Omarchy-based (opinionated
Arch Linux) desktop environment (Hyprland/Omarchy shell/Omarchy theming dotfiles), rootless
Podman container profiles, and the TETHER harness control plan (Go, `127.0.0.1:9191`).

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

`10-layer-stack/observability-stack/` (Docker Compose: Prometheus, Grafana,
node-exporter) — host-metrics substrate. **Not started automatically.**
Operator creates `.env` (the Grafana admin password is *required* — compose
errors at parse time without it) and starts it; ports 31745/31746/31750, all
loopback-bound. See `10-layer-stack/README.md`.

Trace/LLM observability is **not** in this repo: the canonical Langfuse runs
on `127.0.0.1:50598` outside the repository. The duplicate Langfuse and its
OTel Collector (`:31744`) were retired 2026-10-19 — bead `nightforge-aaj`,
see `10-layer-stack/observability-stack/PORT-REGISTRY-PROPOSAL.md`.

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

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:46cd31e7 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
