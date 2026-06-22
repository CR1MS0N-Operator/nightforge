#!/usr/bin/env bash
# CR1MS0N-Operator -- Claude Code hook: block file writes outside project root
# PreToolUse / Write | Edit | MultiEdit

INPUT=$(cat /dev/stdin)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Resolve to absolute path
ABS_PATH=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

# Project root is the cwd when Claude Code was launched
PROJECT_ROOT=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

# Block if target path does not start with project root
if [[ "$ABS_PATH" != "$PROJECT_ROOT"* ]]; then
  echo "BLOCKED: Write to '$ABS_PATH' is outside project root '$PROJECT_ROOT'. Operator executes writes outside project scope manually." >&2
  exit 2
fi

exit 0
