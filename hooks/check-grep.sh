#!/bin/bash
# PreToolUse hook for Bash commands.
# Blocks bare grep/rg invocations — Claude should use the built-in Grep tool
# (which uses ripgrep) instead of shelling out.
INPUT=$(cat)

if echo "$INPUT" | grep -qE '(^|\s|\|)\s*(grep|rg|egrep|fgrep)\s'; then
  echo "BLOCK: Use the built-in Grep tool instead of shelling out to grep/rg."
  echo "The Grep tool uses ripgrep and provides better output for code search."
  exit 2
fi

exit 0
