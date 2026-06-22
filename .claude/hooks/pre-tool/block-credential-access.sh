#!/usr/bin/env bash
# CR1MS0N-Operator -- Claude Code hook: block credential file access via bash
# PreToolUse / Bash

COMMAND=$(cat /dev/stdin | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

if echo "$COMMAND" | grep -qE '(cat|less|head|tail|bat|rg|grep).+(/\.ssh/|/\.gnupg/|id_rsa|id_ed25519|\.pem|\.key)'; then
  echo "BLOCKED: Direct credential file access via bash is not permitted." >&2
  exit 2
fi

exit 0
