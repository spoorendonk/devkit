#!/bin/bash
# PreToolUse hook for Bash commands.
# Blocks branch creation when not on main/master.
INPUT=$(cat)

if echo "$INPUT" | grep -qE 'git (checkout -b|switch -c|branch )'; then
  CURRENT=$(git branch --show-current 2>/dev/null)
  if [ "$CURRENT" != "main" ] && [ "$CURRENT" != "master" ]; then
    echo "BLOCK: You're on '$CURRENT', not main. Switch to main before creating a new branch."
    exit 2
  fi
fi

exit 0
