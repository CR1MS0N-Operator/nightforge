# Security Policy

## Repository Visibility

**This repository is PUBLIC.** Everything committed to `main` is visible to
anyone with access to the remote. Treat committed content as public:

- No credentials, API keys, tokens, or secrets — ever
- No operational data: running process names, keybinds, file paths,
  hostnames, internal IPs, or engagement details
- Redact anything operator-specific with `[REDACTED - operator-specific]`

## Supported Versions

Rolling-release operator workstation configuration. No versioned releases —
security fixes are applied to the `main` branch.

## Reporting a Vulnerability

For operational security reasons, **do not file public issues** for security
vulnerabilities.

- **GitHub Issues**: tag with the `security` label for low-sensitivity items
- **Direct message**: for sensitive disclosures, reach out via GitHub to
  CR1MS0N-Operator

## OPSEC Commitments

- No hardcoded credentials, API keys, or tokens in this repository
- Secrets use environment-variable references or placeholder values
- `.gitignore` blocks secret-bearing files (`*.env`, `.env.*`) and build
  artifacts (`harnessd`, `nightforged`, `*.tar`, `target/`)
- Internal IP ranges (10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12) appear only
  in documentation examples
- Session handoffs (`docs/archive/`) are sanitized templates only — never
  commit operational data in handoff notes

## Remediation Log

- **2026-08-01** — removed an embedded credential from the local `forgejo`
  remote URL in `.git/config`. No secret content is present in this
  repository; details in [CHANGELOG.md](CHANGELOG.md).

## Network Posture

- `harnessd` binds **127.0.0.1:9191** only — no remote access
- Go daemon makes zero external network calls (only `go-chi/chi/v5` + stdlib)
- CORS middleware allows local development origins only (`GET`, `OPTIONS`)
- Observability stack services bind loopback only (31745, 31746, 31750, see
  `10-layer-stack/README.md`) — **not started automatically**; operator
  populates `.env` before first run. The only secret is the Grafana admin
  password, and it is declared `${GRAFANA_ADMIN_PASSWORD:?...}` so compose
  fails at parse time rather than starting with a placeholder credential.
- Trace/LLM telemetry goes to the canonical Langfuse on `127.0.0.1:50598`,
  which runs outside this repository

## Container Security

- All container profiles run rootless via Podman (`--userns=keep-id`)
- Builds use host networking for package downloads; runtime uses bridge
  networking with minimal capabilities (`NET_RAW`, `NET_ADMIN`)
- Engagement directories are mounted read-write; application-level isolation
  is the operator's responsibility

## Secure Development

- CI enforces `go build` + `go vet` and `bash -n` syntax checks
- Removed components (`session-tracker`, `dashboard-ctl`, `.claude/`, …) are
  gitignored to prevent accidental reintroduction
- Scripts avoid `eval`/command injection patterns; secrets stay out of
  command lines

## OPSEC Guidelines for Documentation

- Docs must describe the environment generically; never name real running
  processes, bind keybinds, or quote live config paths
- Use the sanitized templates in `docs/archive/` for any handoff content
- If a doc needs to reference something sensitive, write
  `[REDACTED - operator-specific]` and keep the detail out of the repo

## Known Security Considerations

- `dotfiles/` contains personal workstation configuration — review before
  sharing externally
- Deployed dotfiles (`dotfiles/matugen/`) reflect live desktop state and are
  operator-owned
- `data/` contains operator telemetry — never commit new entries
