# Global Agent Rules

## Output
- Diffs only unless prose requested. 3 bullet max. No summaries.
- Fenced blocks with language tag always.
- Prefer atomic commits over batched.

## Git
- review/* branch prefix required. No main pushes.
- Multi-line bullets: why not what. No Co-Authored-By.

## NEVER
- Write outside project dir. Modify ~/.ssh, /etc/wireguard, or /etc/nftables.conf.
- Commit tokens, keys, passwords, credentials.
- Generate code operator should write themselves (write-first rule).

## OPSEC
- Confirm before destructive bash. Redact 10.0.0.0/24 and 192.168.1.0/24 from external output.