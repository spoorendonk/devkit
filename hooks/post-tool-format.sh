#!/bin/bash
# PostToolUse hook for Write|Edit events.
# Auto-formats files and runs fast checks.
# Receives tool use JSON on stdin; CLAUDE_FILE_PATH is set by Claude Code.

FILE="$CLAUDE_FILE_PATH"
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

EXT="${FILE##*.}"

case "$EXT" in
  cpp|cc|cxx|h|hpp|hxx)
    # Auto-format C++ (non-blocking)
    if command -v clang-format &>/dev/null; then
      clang-format -i "$FILE"
    fi
    ;;

  sh|bash)
    # Auto-format shell scripts (non-blocking)
    if command -v shfmt &>/dev/null; then
      shfmt -w "$FILE"
    fi
    ;;

  py)
    source "$(dirname "$0")/resolve-venv.sh"

    # Auto-format Python (non-blocking)
    if [ -x "$VENV_BIN/ruff" ]; then
      "$VENV_BIN/ruff" format --quiet "$FILE"
      "$VENV_BIN/ruff" check --fix --quiet "$FILE"
    fi

    # Complexity check (blocking)
    if [ -x "$VENV_BIN/ruff" ]; then
      COMPLEXITY=$("$VENV_BIN/ruff" check --select C901 --no-fix "$FILE" 2>&1)
      if [ $? -ne 0 ] && [ -n "$COMPLEXITY" ]; then
        echo "Complexity violation:"
        echo "$COMPLEXITY"
        echo ""
        echo "Don't just extract methods mechanically. Ask: what are the independent"
        echo "responsibilities here? Split along those boundaries. If the function is"
        echo "genuinely complex because the domain is complex, add a comment explaining why."
        exit 2
      fi
    fi

    # Type checking via mypy daemon (blocking)
    if [ -x "$VENV_BIN/dmypy" ]; then
      # Start daemon if not running
      "$VENV_BIN/dmypy" status &>/dev/null || "$VENV_BIN/dmypy" start --log-file /tmp/dmypy.log &>/dev/null

      TYPECHECK=$("$VENV_BIN/dmypy" check "$FILE" 2>&1)
      if [ $? -ne 0 ] && [ -n "$TYPECHECK" ]; then
        # Filter out "Success" messages and empty results
        if ! echo "$TYPECHECK" | grep -q "^Success"; then
          echo "Type error:"
          echo "$TYPECHECK"
          exit 2
        fi
      fi
    fi
    ;;
esac

exit 0
