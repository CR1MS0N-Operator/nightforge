#!/usr/bin/env bash
# CR1MS0N-Operator -- Claude Code hook: block pipe-to-shell execution
# PreToolUse / Bash

COMMAND=$(cat /dev/stdin | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

if echo "$COMMAND" | grep -qE '(curl|wget).+\|\s*(bash|sh)'; then
  echo "BLOCKED: Pipe-to-shell execution is not permitted. Download the file first, inspect it, then execute manually." >&2
  exit 2
fi

exit 0
