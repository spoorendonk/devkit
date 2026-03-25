#!/bin/bash
# PreToolUse hook for Bash commands.
# If a .venv exists in the project but VIRTUAL_ENV is not set,
# blocks bare python/pip commands and tells Claude to use the venv path.
INPUT=$(cat)

# Only check if the command involves Python
if echo "$INPUT" | grep -qE '(^|\s)(python3?(\.[0-9]+)?|pip3?|pytest|mypy|dmypy|ruff)\s'; then
  # Already in a venv — all good
  [ -n "$VIRTUAL_ENV" ] && exit 0

  # Look for a venv in the project
  VENV_DIR=""
  [ -d ".venv" ] && VENV_DIR=".venv"
  [ -d "venv" ] && VENV_DIR="venv"

  if [ -n "$VENV_DIR" ]; then
    # Venv exists but not activated — block bare commands
    if ! echo "$INPUT" | grep -qE "(^|\s)\.?/?$VENV_DIR/bin/"; then
      echo "BLOCK: A virtualenv exists at $VENV_DIR/ but is not activated."
      echo "Use the venv's Python directly instead of bare commands:"
      echo "  $VENV_DIR/bin/python instead of python"
      echo "  $VENV_DIR/bin/pip instead of pip"
      echo "  $VENV_DIR/bin/pytest instead of pytest"
      exit 2
    fi
  else
    # No venv found at all
    echo "BLOCK: No virtualenv found. Create one before running Python commands:"
    echo "  python3 -m venv .venv"
    echo "  uv venv"
    exit 2
  fi
fi

exit 0
