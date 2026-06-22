#!/usr/bin/env bash
# CR1MS0N-Operator -- Claude Code hook: block destructive filesystem commands
# PreToolUse / Bash

COMMAND=$(cat /dev/stdin | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f|rm\s+-[a-zA-Z]*f[a-zA-Z]*r'; then
  echo "BLOCKED: Recursive force removal is not permitted." >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'sudo rm'; then
  echo "BLOCKED: sudo rm is not permitted. Operator executes privileged deletions manually." >&2
  exit 2
fi

exit 0
