#!/usr/bin/env bash
# CR1MS0N-Operator -- Claude Code hook: block direct push to main/master, enforce review/ branch prefix
# PreToolUse / Bash
# Security model: hook enforces push destination only. Operator inspects content at merge.
# No branch is unconditionally trusted -- --force is blocked regardless of destination.

COMMAND=$(cat /dev/stdin | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only evaluate git push commands
if ! echo "$COMMAND" | grep -qE '^git push'; then
  exit 0
fi
# Block bare git push (no remote/branch specified) -- forces explicit branch naming
if echo "$COMMAND" | grep -qE '^git push$'; then
  echo "BLOCKED: Bare 'git push' is not permitted. Specify explicit remote and branch: git push origin review/branch-name" >&2
  exit 2
fi


# Block force push regardless of branch -- no destination is unconditionally trusted
if echo "$COMMAND" | grep -qE 'git push.+--force'; then
  echo "BLOCKED: Force push is not permitted to any branch, including review/*." >&2
  exit 2
fi

# Block direct push to main or master
if echo "$COMMAND" | grep -qE 'git push.+(main|master)'; then
  echo "BLOCKED: Direct push to main/master is not permitted. Use a review/ branch and merge manually." >&2
  exit 2
fi

# Block push to any branch not prefixed review/
if echo "$COMMAND" | grep -qE 'git push\s+\S+\s+\S+'; then
  BRANCH=$(echo "$COMMAND" | grep -oE 'git push\s+\S+\s+(\S+)' | awk '{print $NF}')
  if [ -n "$BRANCH" ] && ! echo "$BRANCH" | grep -qE '^review/'; then
    echo "BLOCKED: Claude Code may only push to review/* branches. Branch '$BRANCH' is not permitted. Operator merges to main manually." >&2
    exit 2
  fi
fi

exit 0
