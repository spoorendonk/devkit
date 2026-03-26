#!/bin/bash
# Git pre-push hook.
# Final gate before sharing code — catches what pre-commit doesn't.
#
# Flow:
#   1. Review check → warn if /review not run
#   2. Remaining issues (complexity, type errors, warnings) → warn and continue
#
# Formatting, lint fixes, and tests run at pre-commit time.

set -e

# Get changed files vs main
MAIN_BRANCH="main"
git rev-parse --verify "origin/$MAIN_BRANCH" &>/dev/null || MAIN_BRANCH="master"
git fetch origin "$MAIN_BRANCH" --quiet 2>/dev/null || true
CHANGED_FILES=$(git diff --name-only "origin/$MAIN_BRANCH"...HEAD 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || true)

[ -z "$CHANGED_FILES" ] && exit 0

CPP_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(cpp|cc|cxx|h|hpp|hxx)$' || true)
PY_FILES=$(echo "$CHANGED_FILES" | grep -E '\.py$' || true)
SH_FILES=$(echo "$CHANGED_FILES" | grep -E '\.sh$' || true)

# ============================================================
# Step 1: Review check (warn if /review not run)
# ============================================================

REVIEW_STALE=0
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)

if [ -f ".claude/.last-review" ]; then
  LAST_REVIEWED=$(cat .claude/.last-review | tr -d '[:space:]')
  if [ "$LAST_REVIEWED" != "$CURRENT_HEAD" ]; then
    COMMITS_SINCE=$(git rev-list --count "$LAST_REVIEWED..$CURRENT_HEAD" 2>/dev/null || echo "?")
    echo ""
    echo "=== Review check ==="
    echo "WARNING: /review has not been run since $COMMITS_SINCE commit(s) ago."
    REVIEW_STALE=1
  fi
else
  echo ""
  echo "=== Review check ==="
  echo "WARNING: /review has never been run on this branch."
  REVIEW_STALE=1
fi

if [ "$REVIEW_STALE" -ne 0 ]; then
  echo ""
  echo "Push blocked: run /review first."
  exit 1
fi

# ============================================================
# Step 2: Remaining issues (warn and continue)
# ============================================================

ISSUES=""

# clang-tidy (non-fixable warnings)
if [ -n "$CPP_FILES" ] && command -v clang-tidy &>/dev/null; then
  COMPILE_DB=""
  [ -f "build/compile_commands.json" ] && COMPILE_DB="-p build"
  [ -f "compile_commands.json" ] && COMPILE_DB="-p ."

  if [ -n "$COMPILE_DB" ]; then
    echo ""
    echo "=== Running clang-tidy ==="

    for f in $CPP_FILES; do
      [ -f "$f" ] || continue
      RESULT=$(clang-tidy $COMPILE_DB \
        --quiet "$f" 2>&1 || true)
      if echo "$RESULT" | grep -qE '(warning|error):'; then
        ISSUES="${ISSUES}${RESULT}"$'\n'
      fi
    done
  fi
fi

# ruff complexity (C901, not auto-fixable)
if [ -n "$PY_FILES" ] && command -v ruff &>/dev/null; then
  for f in $PY_FILES; do
    [ -f "$f" ] || continue
    RESULT=$(ruff check --select C901 --no-fix "$f" 2>&1 || true)
    if [ -n "$RESULT" ] && ! echo "$RESULT" | grep -q "^All checks passed"; then
      ISSUES="${ISSUES}${RESULT}"$'\n'
    fi
  done
fi

# shellcheck warnings
if [ -n "$SH_FILES" ] && command -v shellcheck &>/dev/null; then
  for f in $SH_FILES; do
    [ -f "$f" ] || continue
    RESULT=$(shellcheck "$f" 2>&1 || true)
    if [ -n "$RESULT" ]; then
      ISSUES="${ISSUES}${RESULT}"$'\n'
    fi
  done
fi

# mypy type errors
if [ -n "$PY_FILES" ] && command -v mypy &>/dev/null; then
  echo ""
  echo "=== Running mypy ==="
  RESULT=$(mypy --strict $PY_FILES 2>&1 || true)
  if echo "$RESULT" | grep -qE '(error):'; then
    ISSUES="${ISSUES}${RESULT}"$'\n'
  else
    echo "mypy: clean"
  fi
fi

# If issues found, warn but allow push
if [ -n "$ISSUES" ]; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  Issues found:"
  echo "═══════════════════════════════════════════"
  echo "$ISSUES"
  echo "═══════════════════════════════════════════"
  echo ""
  echo "Warning: pushing with known issues."
else
  echo ""
  echo "All checks passed."
fi

# Clean up review stamp so next changes require a fresh review
rm -f .claude/.last-review

exit 0
