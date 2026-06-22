#!/usr/bin/env bash
# CR1MS0N-Operator -- Claude Code hook: block autonomous infra commands
# PreToolUse / Bash

COMMAND=$(cat /dev/stdin | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

if echo "$COMMAND" | grep -qE 'sudo (wg-quick|wg) '; then
  echo "BLOCKED: WireGuard commands must be executed manually by the operator. Never run autonomously." >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'sudo nixos-rebuild'; then
  echo "BLOCKED: nixos-rebuild must be executed manually by the operator after reviewing configuration changes." >&2
  exit 2
fi

exit 0
