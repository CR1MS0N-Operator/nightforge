# 10-Layer Stack

Implementation home for the CR1MS0N self-improving harness architecture (L1–L10).

Source framework: AlphaSignal, *"10 Layers of Self-Improving Harness Stack"* (2026-06-16).
Alignment audit and per-layer gap analysis live in the vault at
`~/Documents/ai-lab-vault/80-Operations/10-layer-alignment-audit.md`.

This directory replaces the former empty `10-Stack/` scaffolding — the two naming
schemes are consolidated into the single name `10-layer-stack/`.

## The layers

| Layer | Name | Purpose | Status |
|-------|------|---------|--------|
| L1 | Stable Substrate | What stays fixed while the harness changes: base model, runtime, tools, task interface, evaluator, permissions | Implemented |
| L2 | Trace Log | The path, not just the answer: tool calls, file reads, retries, verifier output, costs, failures, state changes | Implemented |
| L3 | External State | Learning kept outside the model — skills, memory, natural-language policies, tool wrappers | Implemented |
| L4 | Failure Mining | Select the failures that teach a reusable lesson; do not feed every trace back | Implemented |
| L5 | Proposal Engine | Turn mined evidence into a candidate edit | Partial |
| L6 | Validation Gate | Reject edits that do not survive held-out evaluation. Without it the loop just overfits | Implemented |
| L7 | Versioning / Rollback | The harness should look like a repo, not a memory blob | Implemented |
| L8 | Routing & Variants | One harness cannot carry every lesson forever — route per task class | Implemented |
| L9 | Benefit Measurement | A harness update is not the same thing as a better agent; measure the delta | Designed (S190) — Phase 0 planned |
| L10 | Weight Update | Last resort, for behavior the harness cannot express | Designed (S190) — deferred, preconditions listed |

## Directory structure

```
10-layer-stack/
└── observability-stack/          # host metrics substrate (L4 health)
    ├── docker-compose.yml        # prometheus, grafana, node-exporter
    ├── prometheus.yml            # scrape config
    ├── nightforge-metrics.json   # host metrics dashboard
    ├── grafana-provisioning/
    │   ├── datasources/prometheus.yml
    │   └── dashboards/provider.yml
    ├── PORT-REGISTRY-PROPOSAL.md # port rows for the vault registry
    └── .env.example              # secret placeholders; copy to .env, never commit
```

New layer implementations get their own sibling directory here (for example
`proposal-engine/` for L5 or `benefit-measurement/` for L9).

## observability-stack

**What this stack is now:** host metrics only — Prometheus scrapes
node-exporter, Grafana visualises it. That is the part that measured
something real and was not duplicated by anything else.

**What was retired on 2026-10-19** (bead `nightforge-aaj`, operator decision
"drop the competing Langfuse"):

| Removed | Why | What serves it instead |
|---------|-----|------------------------|
| `langfuse-web`, `langfuse-worker`, `postgres`, `clickhouse`, `minio`, `redis` | A second Langfuse that never ran. No `cr1mson-observability` volumes were ever created on the host. | The canonical Langfuse at `127.0.0.1:50598` (docker project `langfuse`, compose at `~/Documents/ai-lab-vault/20-Tools/agentsview-langfuse-setup/langfuse/`), which is registered in the port registry and is the live instance. |
| `otel-collector` | Its only exporter destination was the duplicate Langfuse above. No producer targets `:31744`. | OMP exports OTLP straight to `127.0.0.1:50598` (`cr1ms0n-otel-env.service` → `otel-env-render.sh`); dsh session logs go via the `cr1ms0n-otel-env-logsbridge.service` bridge on `127.0.0.1:14318` → `50598`. |
| `otel-collector.yml` | Config for the retired collector. | — |
| `grafana-dashboard.json` (four-agent dashboard) | Every panel queried a metric nothing emits (`harness_*`, `agentgateway_*`, `DCGM_FI_DEV_GPU_UTIL`). | `nightforge-metrics.json` — only panels backed by node-exporter. |

Ports (all loopback-bound). The authoritative registry is
`~/Documents/ai-lab-vault/05-Architecture/port-registry.md`; the rows this
stack still needs are written out in
[`observability-stack/PORT-REGISTRY-PROPOSAL.md`](observability-stack/PORT-REGISTRY-PROPOSAL.md):

| Port | Service | Bind | Status |
|------|---------|------|--------|
| 31745 | Prometheus UI/API | 127.0.0.2 | configured, down (operator-started) |
| 31746 | Grafana | 127.0.0.1 | configured, down (operator-started) |
| 31750 | node-exporter | 127.0.0.1 | configured, down (operator-started) |

Prometheus binds the loopback alias `127.0.0.2` so the number cannot collide
with a future `127.0.0.1:31745` service. The old dual-role claim on `31745`
(AgentGateway stats on `127.0.0.1`, Prometheus on `127.0.0.2`) is gone —
AgentGateway was purged from the fleet on 2026-08-16.

### Startup (operator only)

The stack is **not** started automatically. Before first run, create `.env`
with a real Grafana admin password:

```bash
cd ~/Projects/nightforge/10-layer-stack/observability-stack
cp .env.example .env
printf 'GRAFANA_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 16)" >> .env
```

> **Path note:** the repository lives at `~/Projects/nightforge`.
> `~/Github/nightforge` **does not exist** on this workstation — `~/Github`
> is not present at all. The old startup path in this file was wrong and
> resolved to nothing.

`GRAFANA_ADMIN_PASSWORD` is **required**: `docker-compose.yml` uses
`${GRAFANA_ADMIN_PASSWORD:?...}`, so compose refuses to parse the file when
the variable is unset or empty. A missing `.env` fails loudly instead of
starting Grafana with a placeholder password.

Then start:

```bash
docker compose --env-file .env up -d
```

Restart / stop:

```bash
docker compose --env-file .env restart prometheus grafana
docker compose --env-file .env down
```

Do not run `docker compose down -v` — it destroys the persisted named volumes
(`prometheus_data`, `grafana_data`).

Full operator procedure for the canonical Langfuse and the trace pipeline:
`~/Documents/ai-lab-vault/20-Tools/agentsview-langfuse-setup/langfuse.md` and
`~/Documents/ai-lab-vault/.dsh-work/observability/README.md`.
