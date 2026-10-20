# observability-stack troubleshooting

> **2026-10-19 (bead `nightforge-aaj`) — the Langfuse section below is
> retired history.** The duplicate Langfuse in this stack was removed (the
> canonical instance is `127.0.0.1:50598`, outside this repo). The
> surviving stack is Prometheus + Grafana + node-exporter. Read the current
> faults first; the historical section is kept because it records a real
> failure mode that still applies to anything that bakes a credential at
> volume-init time.

## Current stack: prometheus + grafana + node-exporter

### The stack will not start: "GRAFANA_ADMIN_PASSWORD is required"

**Symptom:** `docker compose up -d` fails at parse time.

**Cause:** by design. `docker-compose.yml` uses
`${GRAFANA_ADMIN_PASSWORD:?...}` so a missing or empty value is a hard
error instead of a silent placeholder.

**Fix:**

```bash
cd ~/Projects/nightforge/10-layer-stack/observability-stack
cp .env.example .env
printf 'GRAFANA_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 16)" >> .env
docker compose --env-file .env up -d
```

> **Path note:** the repository is at `~/Projects/nightforge`.
> `~/Github/nightforge` does not exist on this workstation — `~/Github` is
> not present at all. Any command using the old path fails with
> "No such file or directory".

### Prometheus shows only one target, and it is `node`

**Symptom:** the `agentgateway` and `harnessd` jobs are gone from
`prometheus.yml`.

**Why:** both were removed on 2026-10-19 because they pointed at nothing.

- `agentgateway` → `127.0.0.1:31745`: AgentGateway was deprecated/purged
  from the fleet (S189 transition, 2026-08-16). Nothing listens on that
  address and nothing ever will.
- `harnessd` → `127.0.0.1:9191`: the control plane does not serve a
  Prometheus endpoint. `cmd/harnessd/main.go` builds
  `internal/api.NewRouter()`, which registers no `/metrics` route — verified
  2026-10-19 by exercising the router (`GET /metrics` → 404). The
  `/metrics` handler in `internal/handler/metrics.go` belongs to
  `internal/server`, a package no binary imports.

**To bring harnessd metrics back**, register `/metrics` on the *served*
router (`internal/api`) — that is a code change, not a config change. Do not
re-add the scrape target before the endpoint exists; it would be another
permanently-down target.

### Grafana dashboard panels are empty

**Symptom:** panels show "No data".

**Why:** the old four-agent dashboard queried `harness_*`,
`agentgateway_*` and `DCGM_FI_DEV_GPU_UTIL` — metrics no exporter in this
fleet produces. It was replaced by `nightforge-metrics.json`, which only
queries node-exporter series.

### Grafana keeps the old password after changing `.env`

**Symptom:** the new `GRAFANA_ADMIN_PASSWORD` is rejected; the old one
still works.

**Why:** Grafana applies the admin password only when it initialises its
database. On an existing `grafana_data` volume a changed `.env` value is
ignored.

**Fix (keeps dashboards and history):**

```bash
GP=$(grep '^GRAFANA_ADMIN_PASSWORD=' .env | cut -d= -f2)
docker exec cr1mson-observability-grafana-1 \
  grafana cli --homepath /usr/share/grafana admin reset-admin-password "$GP"
```

Always verify a rotated password actually took effect by confirming the
*old* one now fails:

```bash
curl -u admin:"$GP" 127.0.0.1:31746/api/datasources   # 200
curl -u admin:OLD_PASSWORD 127.0.0.1:31746/api/datasources  # 401
```

General rule: **any service that only reads a credential at volume-init time
silently ignores a later `.env` change.** Postgres, ClickHouse and MinIO all
behaved this way in the retired Langfuse stack.

### Ports are not listening

Expected: the stack is **operator-started** and is not running by default.
As of 2026-10-19 nothing listens on `31745`, `31746` or `31750`.

```bash
ss -tln | grep -E ':(31745|31746|31750)\b'
```

The canonical Langfuse listens on `127.0.0.1:50598` and is managed outside
this repository — see
`~/Documents/ai-lab-vault/20-Tools/agentsview-langfuse-setup/langfuse.md`.

---

## Retired: Langfuse in this stack (historical)

The following records the failure modes of the Langfuse services that used
to live in this directory. They are kept because they describe real traps —
clustered ClickHouse migrations on a single node, and credentials baked at
volume-init time — that any replacement deployment can hit again. **The
services themselves are gone; nothing here applies to the current stack.**

### Langfuse restart loop (resolved 2026-08-02)

`langfuse-web` and `langfuse-worker` sat in `Restarting (1)` indefinitely while
every other service reported healthy.

Two **independent** faults were stacked. Fixing either one alone leaves the loop
in place, so both are recorded here.

#### Fault 1 — clustered ClickHouse migrations on a single node

`langfuse-web` died during its entrypoint migration step:

```
error: failed to open database: code: 139, message: There is no Zookeeper configuration in server config in line 0:
        CREATE TABLE schema_migrations ON CLUSTER default (
                version    Int64,
                dirty      UInt8,
                sequence   UInt64
        ) Engine=ReplicatedMergeTree ORDER BY sequence
Applying clickhouse migrations failed.
```

`ReplicatedMergeTree` and `ON CLUSTER` require a Zookeeper/ClickHouse Keeper
quorum to coordinate replicas. This deployment was a single ClickHouse node
with no Keeper, so the very first migration — creating `schema_migrations` —
aborted. The entrypoint `exit`s on migration failure, `restart: always`
respawns it, loop.

Langfuse ships both migration sets and selects between them in
`/app/packages/shared/clickhouse/scripts/up.sh`:

```sh
if [ "$CLICKHOUSE_CLUSTER_ENABLED" == "false" ] ; then
  migrate -source file://clickhouse/migrations/unclustered ... x-migrations-table-engine=MergeTree
else
  migrate -source file://clickhouse/migrations/clustered   ... x-migrations-table-engine=ReplicatedMergeTree
fi
```

The flag **defaults to the clustered branch**, and the old `docker-compose.yml`
never set it. Upstream's reference compose does set it in the shared env anchor.

**Fix** — set `CLICKHOUSE_CLUSTER_ENABLED=false` in the shared env anchor, so
web and worker both inherit it. The canonical deployment
(`~/Documents/ai-lab-vault/20-Tools/agentsview-langfuse-setup/langfuse/`)
carries the same setting.

Rejected alternatives:

- *Add Zookeeper/Keeper* — a whole extra service and quorum to operate purely to
  satisfy replication we do not want on one node.
- *PostgreSQL only* — not supported. Langfuse v3+ requires ClickHouse for traces
  and observations; Postgres alone is not a valid backend.

#### Fault 2 — no `.env`, so every secret was a placeholder

`langfuse-worker` never reached the migration step. It crashed earlier, at env
validation:

```
ZodError: ENCRYPTION_KEY must be 256 bits, 64 string characters in hex format,
generate via: openssl rand -hex 32
```

`.env` did not exist. Compose fell back to the `${VAR:-REPLACE_*}` defaults in
`docker-compose.yml`, so `ENCRYPTION_KEY` was the literal
`REPLACE_WITH_64_HEX_CHAR_KEY` (28 chars, fails the exact-64 check).

**Fix** — generate a real `.env` (mode 600, gitignored via `*.env`):

```bash
cd ~/Projects/nightforge/10-layer-stack/observability-stack
umask 077
{
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 24)"
  echo "CLICKHOUSE_PASSWORD=$(openssl rand -hex 24)"
  echo "REDIS_AUTH=$(openssl rand -hex 24)"
  echo "MINIO_ROOT_USER=lfminio$(openssl rand -hex 4)"
  echo "MINIO_ROOT_PASSWORD=$(openssl rand -hex 24)"
  echo "SALT=$(openssl rand -base64 32)"
  echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
  echo "NEXTAUTH_SECRET=$(openssl rand -base64 32)"
  echo "GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 16)"
  echo "CLICKHOUSE_CLUSTER_ENABLED=false"
} >> .env
```

Keep infrastructure passwords **hex/alphanumeric**. `POSTGRES_PASSWORD`,
`CLICKHOUSE_PASSWORD` and `REDIS_AUTH` are interpolated raw into `DATABASE_URL`
and the ClickHouse migration DSN — unencoded `@`, `/`, `#`, `?` corrupt the URL.
The entrypoint even lists this as a suspected cause on any migration failure,
which is a misleading hint when the real problem is the cluster flag.

> This is the exact failure the current stack prevents by construction:
> `${VAR:?...}` makes compose error at parse time rather than substituting a
> placeholder. The canonical Langfuse deployment uses the same rule — its
> `.env` variables have no defaults either.

#### Volume wipe was required

Postgres, ClickHouse and MinIO bake credentials **at volume initialisation
only**. Those volumes had already been created with the `REPLACE_*` placeholders,
so new `.env` values would have auth-failed against the old baked-in ones.

The five Langfuse volumes were dropped; `prometheus_data` and `grafana_data` were
deliberately preserved. Verified lossless first — `system.tables` for database
`default` returned 0, i.e. the migration never once succeeded and no trace data
had ever been written.

```bash
docker compose down
docker volume rm \
  cr1mson-observability_langfuse_clickhouse_data \
  cr1mson-observability_langfuse_clickhouse_logs \
  cr1mson-observability_langfuse_minio_data \
  cr1mson-observability_langfuse_postgres_data \
  cr1mson-observability_langfuse_redis_data
docker compose up -d
```

This was the one sanctioned exception to the README's "do not destroy volumes"
rule, and it applied only to a stack that had never successfully started. Once
Langfuse holds real traces, rotating these passwords is a migration, not a wipe.

#### Grafana kept the placeholder password (caught during verification)

`grafana_data` was **deliberately preserved** through the wipe, which meant
Grafana kept the admin password baked in at its first init — the literal
`REPLACE_BEFORE_START`. `GF_SECURITY_ADMIN_PASSWORD` is applied only when
Grafana initialises its database; it is *not* re-applied on later boots. Adding
the real password to `.env` therefore had no effect, and the placeholder still
authenticated:

```
curl -u admin:REPLACE_BEFORE_START 127.0.0.1:31746/api/datasources  -> 200
curl -u admin:<real .env password>  127.0.0.1:31746/api/datasources -> 401
```

Fixed without destroying the volume (dashboards and history preserved):

```bash
GP=$(grep '^GRAFANA_ADMIN_PASSWORD=' .env | cut -d= -f2)
docker exec cr1mson-observability-grafana-1 \
  grafana cli --homepath /usr/share/grafana admin reset-admin-password "$GP"
```

Now 200 with the `.env` password, 401 with the placeholder, Prometheus datasource
still wired to `http://127.0.0.2:31745`.

### If the Langfuse section ever comes back

1. `docker compose logs langfuse-web --tail 60` — migration/Zookeeper errors.
2. `docker compose logs langfuse-worker --tail 60` — `ZodError` env failures.
   The two services fail for different reasons; always read both.
3. `docker compose config | grep CLICKHOUSE_CLUSTER_ENABLED` must render
   `"false"`. If `.env` is missing, compose silently uses the `REPLACE_*`
   defaults instead of erroring — check `.env` exists before anything else.
   *That silent-fallback behaviour is what the current stack's `${VAR:?...}`
   syntax exists to prevent — do not reintroduce defaults for secrets.*
