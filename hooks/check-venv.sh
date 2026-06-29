#!/bin/bash
# PreToolUse hook for Bash commands.
# If a .venv exists in the project but VIRTUAL_ENV is not set,
# blocks bare python/pip commands and tells Claude to use the venv path.
#
# If the project has no Python infrastructure (no pyproject.toml / setup.py /
# setup.cfg / requirements.txt), the hook passes — Python commands are assumed
# to be standalone utilities that don't need a project-level venv.
#
# This hook operates on the actual shell command (tool_input.command extracted
# from the Claude Code hook JSON), NOT the raw JSON payload. Matching the raw
# JSON is wrong on two counts: (1) the command is wrapped in quotes, so a
# legitimate ".venv/bin/python ..." is preceded by a '"' rather than
# whitespace/start, defeating the allow-check below; (2) the word
# "python"/"pip" can appear as a plain argument (e.g. `find python -type f`).
INPUT=$(cat)

# Extract the shell command from the hook payload. Prefer jq; fall back to
# python3. If we can't parse it out, fail OPEN (exit 0) — never block on a
# payload we can't reliably read, since scanning the raw JSON misfires.
CMD=""
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
fi
if [ -z "$CMD" ] && command -v python3 >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | python3 -c \
    'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' \
    2>/dev/null)
fi
[ -z "$CMD" ] && exit 0

# Always allow venv-creation/bootstrap commands. Otherwise the "no virtualenv
# found" branch below would block the very command it tells the user to run.
if echo "$CMD" | grep -qE '(python3?([.][0-9]+)?[[:space:]]+-m[[:space:]]+venv|(^|[[:space:]])(uv[[:space:]]+venv|virtualenv)([[:space:]]|$))'; then
  exit 0
fi

# Strip quoted string literals so tool names inside messages/arguments (e.g. a
# commit message "fix; mypy clean") are not mistaken for real invocations.
SCAN=$(printf '%s' "$CMD" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# Detect a Python tool only when it sits at *command position*: the start of the
# command or right after a shell separator (; & | ( { && ||), optionally behind
# leading VAR=value assignments. This matches `python ...`, `cd x && pytest`,
# `FOO=1 mypy ...` but not `find python` or `cat foo_pytest.txt`, and not a
# path-qualified `.venv/bin/python` (which is already correct usage).
TOOLS='python3?([.][0-9]+)?|pip3?|pytest|mypy|dmypy|ruff'
CMDPOS='(^|[;&|({]|&&|\|\|)[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
if echo "$SCAN" | grep -qE "${CMDPOS}(${TOOLS})([[:space:]]|$)"; then
  # Already in a venv — all good
  [ -n "$VIRTUAL_ENV" ] && exit 0

  # No Python project metadata — treat as standalone utility, skip venv check
  if [ ! -f "pyproject.toml" ] && [ ! -f "setup.py" ] && [ ! -f "setup.cfg" ] && [ ! -f "requirements.txt" ]; then
    exit 0
  fi

  # Look for a venv in the project
  VENV_DIR=""
  [ -d ".venv" ] && VENV_DIR=".venv"
  [ -d "venv" ] && VENV_DIR="venv"

  if [ -n "$VENV_DIR" ]; then
    # Venv exists but not activated — allow only if the command already invokes
    # the venv's tools directly (.venv/bin/...) or targets it (uv --python ...).
    if ! echo "$CMD" | grep -qE "(^|[[:space:]])\.?/?$VENV_DIR/bin/"; then
      echo "BLOCK: A virtualenv exists at $VENV_DIR/ but is not activated."
      echo "Use the venv's Python directly instead of bare commands:"
      echo "  $VENV_DIR/bin/python instead of python"
      echo "  $VENV_DIR/bin/pip instead of pip"
      echo "  $VENV_DIR/bin/pytest instead of pytest"
      exit 2
    fi
  else
    # Python project but no venv found
    echo "BLOCK: No virtualenv found. Create one before running Python commands:"
    echo "  python3 -m venv .venv"
    echo "  uv venv"
    exit 2
  fi
fi

exit 0
