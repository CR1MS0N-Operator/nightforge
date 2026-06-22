# Security Policy

## Supported Versions

This project is a rolling-release operator workstation configuration. There are no versioned releases — security fixes are applied to the `main` branch.

## Reporting a Vulnerability

For operational security reasons, please **do not file public issues** for security vulnerabilities.

Instead, contact the maintainer directly:
- **GitHub Issues**: Tag with `security` label for low-sensitivity items
- **Direct message**: For sensitive disclosures, reach out via GitHub to CR1MS0N-Operator

## OPSEC Commitments

- No hardcoded credentials, API keys, or tokens in this repository
- All secrets use environment variable references (`{env:VAR_NAME}`) or placeholder values (`your_key_here`)
- Telemetry and error reporting are explicitly disabled in all tooling configurations
- Internal IP ranges (10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12) appear only in documentation examples

## Container Security

- All container profiles run rootless via Podman (`--userns=keep-id`)
- Container builds use host networking; runtime uses bridge networking with minimal capabilities
- Engagement directories are mounted read-write but application-level isolation is the operator's responsibility

## Secure Development

This project uses:
- Pre-commit hooks that block credential access, destructive commands, and path boundary violations
- `shellcheck`-compatible patterns in shell scripts
- Rust with `#![forbid(unsafe_code)]` patterns (no unsafe blocks)
- Go with no external network calls in operational binaries
