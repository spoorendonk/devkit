#!/bin/bash
# Resolve Python venv. Sourced by other hooks.
# Sets VENV_BIN on success, exits with error if no venv found.
#
# Usage:
#   source "$(dirname "$0")/resolve-venv.sh"

VENV_DIR=""
[ -d ".venv" ] && VENV_DIR=".venv"
[ -d "venv" ] && VENV_DIR="venv"

if [ -z "$VENV_DIR" ]; then
  echo "FAILED: No virtualenv found. Create one first:"
  echo "  python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'"
  exit 2
fi

VENV_BIN="$VENV_DIR/bin"
