# Port Registry Proposal — NightForge Observability Stack

**Bead:** `nightforge-aaj` (P0, verified 2026-09-28)
**Prepared:** 2026-10-19
**Authoritative registry:** `~/Documents/ai-lab-vault/05-Architecture/port-registry.md`
(vault-owned; this file is the change request, not the registry itself)

The authoritative registry has **no rows** for `31744`–`31750` or `9191`
(verified 2026-10-19 by grep over the registry file). The rows below are the
exact entries that would be needed, with the justification for each. **No port
is invented here** — every number was already in use by this stack's compose
file, and each row states whether the listener is up or down at verification
time.

Verified listening state on 2026-10-19 (`ss -tln`, host context):

```
127.0.0.1:14318   127.0.0.1:3080    127.0.0.1:39110   127.0.0.1:39111
127.0.0.1:50598   127.0.0.1:50898   127.0.0.1:50899   127.0.0.1:50901
127.0.0.1:54118   127.0.0.1:55439   127.0.0.1:61821   127.0.0.1:631
127.0.0.1:63110   127.0.0.1:64172   127.0.0.1:64753   127.0.0.1:9230
```

None of `31744`, `31745`, `31746`, `31747`, `31750`, `9191` was listening.

---

## Rows to add

### §1 — Listening now (add only when verified up)

These three are the survivors of the 2026-10-19 cleanup. They are **down**
today because the stack is operator-started and not running, so they belong
in §2 (configured but down) until the operator brings them up. They are
listed here so the registry has the intended topology on record.

| Port | Bind | Service | Owner | Status | Verified |
|------|------|---------|-------|--------|----------|
| 31745 | 127.0.0.2 | Prometheus UI/API — metrics stack | observability (docker) | **down** — configured, operator-started | 2026-10-19 |
| 31746 | 127.0.0.1 | Grafana — host metrics dashboard | observability (docker) | **down** — configured, operator-started | 2026-10-19 |
| 31750 | 127.0.0.1 | node-exporter — host CPU/mem/disk/load | observability (docker) | **down** — configured, operator-started | 2026-10-19 |

**Why `127.0.0.2` for Prometheus:** the loopback alias is kept so the number
`31745` cannot collide with a future `127.0.0.1:31745` service. The old
dual-role claim on this port (AgentGateway stats on `127.0.0.1:31745`,
Prometheus on `127.0.0.2:31745`) is obsolete: AgentGateway was purged from
the fleet on 2026-08-16 and nothing listens on `127.0.0.1:31745`.

### §4 — Decommissioned (add as decommissioned, do not use)

| Port | Was | Note |
|------|-----|------|
| 31744 | OTel Collector OTLP gRPC | **RETIRED 2026-10-19 (bead `nightforge-aaj`).** The collector's only exporter destination was the duplicate Langfuse in this repo, which was itself retired the same day. The canonical trace path does not use a collector: OMP exports OTLP directly to Langfuse on `127.0.0.1:50598` (`~/.config/systemd/user/cr1ms0n-otel-env.service` → `otel-env-render.sh`), and dsh session logs go through the `cr1ms0n-otel-env-logsbridge.service` bridge on `127.0.0.1:14318` → `50598`. No producer targets `:31744`. |
| 31745 (127.0.0.1) | AgentGateway `/metrics` | **RETIRED 2026-10-19.** AgentGateway was deprecated/purged (S189 transition, 2026-08-16). The `127.0.0.1` half of the old dual-role `31745` no longer has any owner; `127.0.0.2:31745` is Prometheus (see §1 above). |
| 31747 | Langfuse (duplicate) | **RETIRED 2026-10-19.** The canonical Langfuse is `127.0.0.1:50598` (already registered, docker project `langfuse`, compose at `~/Documents/ai-lab-vault/20-Tools/agentsview-langfuse-setup/langfuse/`). This repo's second Langfuse never ran — no `cr1mson-observability` volumes were ever created, and the only Langfuse volumes on the host are `langfuse_langfuse_*`. |
| 9191 | harnessd (Prometheus scrape target) | **NOT REGISTERED — and now not a scrape target.** harnessd itself is a real service on `127.0.0.1:9191` and is referenced by the repo's own docs, but it is not in this registry. It was never a *stack* port. It was removed from `prometheus.yml` on 2026-10-19 because the served router (`internal/api.NewRouter()`, built by `cmd/harnessd/main.go`) registers no `/metrics` route — `GET /metrics` returns 404 (verified by exercising the router). The `/metrics` handler in `internal/handler/metrics.go` belongs to `internal/server`, which no binary imports. Registering `9191` here would be wrong: it is a TETHER control-plane port, not an observability-stack port. If the operator wants harnessd metrics, the fix is to register `/metrics` on the served router — a code change, not a registry change. |

---

## What the operator needs to do

1. Paste the §1 and §4 rows into
   `~/Documents/ai-lab-vault/05-Architecture/port-registry.md`.
2. Bump the registry's `verified:` date to `2026-10-19` and add the sweep
   note that `31744`/`31747` are decommissioned and `31745`/`31746`/`31750`
   are configured-but-down.
3. Optionally add a `9191` row for harnessd in a **TETHER** context if the
   registry wants to cover the control plane — it is not part of the
   observability stack and this change does not depend on it.

## Note on the duplicate Langfuse

The duplicate Langfuse in this repo was **never running**; the canonical one
at `:50598` is. The 2026-10-19 cleanup deleted the duplicate's service
definitions from `10-layer-stack/observability-stack/docker-compose.yml` and
the OTel Collector that fed it. The canonical Langfuse and its backing
services are untouched — they live outside this repository, in the vault at
`20-Tools/agentsview-langfuse-setup/langfuse/`, docker project `langfuse`.
