#!/bin/bash
# Git pre-push hook.
# Final gate before sharing code — catches what pre-commit doesn't.
#
# Flow:
#   1. Review check → block if /review not run
#   2. Clean build + test → block on failure
#   3. Remaining issues (complexity, type errors, warnings) → warn and continue

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

# Check if only non-code files changed (skip build+test for docs-only pushes)
CODE_FILES=$(echo "$CHANGED_FILES" | grep -vE '^(\.devkit/|LICENSE|CHANGELOG)' | grep -vE '\.(md|txt|rst)$' | grep -vE '^\.(gitignore|gitattributes)$' || true)

# ============================================================
# Step 1: Review check (block if /review not run)
# ============================================================

REVIEW_STALE=0
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)

if [ -f ".devkit/.last-review" ]; then
  LAST_REVIEWED=$(cat .devkit/.last-review | tr -d '[:space:]')
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
# Step 2: Clean build + test (hard block)
# ============================================================

# Extract a fenced code block under "## Build & Test" by tag (e.g. ```build ... ```)
extract_block() {
  local tag="$1"
  if [ -f "CLAUDE.md" ]; then
    sed -n -e '/^## Build & Test/,/^## /{' \
      -e "/^\`\`\`${tag}$/,/^\`\`\`$/{ /^\`\`\`/d; p; }" \
      -e '}' CLAUDE.md
  fi
}

if [ -z "$CODE_FILES" ]; then
  echo ""
  echo "=== Skipping build+test (docs-only) ==="
else
  BUILD_FAILED=0
  CLEAN_CMD=$(extract_block clean)
  BUILD_CMD=$(extract_block build)
  TEST_CMD=$(extract_block test)

  if [ -n "$BUILD_CMD" ] || [ -n "$TEST_CMD" ]; then
    # Use commands from CLAUDE.md
    if [ -n "$CLEAN_CMD" ]; then
      echo ""
      echo "=== Clean ==="
      set +e; eval "$CLEAN_CMD"; rc=$?; set -e
      if [ "$rc" -ne 0 ]; then BUILD_FAILED=1; fi
    fi
    if [ -n "$BUILD_CMD" ] && [ "$BUILD_FAILED" -eq 0 ]; then
      echo ""
      echo "=== Build ==="
      set +e; eval "$BUILD_CMD"; rc=$?; set -e
      if [ "$rc" -ne 0 ]; then BUILD_FAILED=1; fi
    fi
    if [ -n "$TEST_CMD" ] && [ "$BUILD_FAILED" -eq 0 ]; then
      echo ""
      echo "=== Test ==="
      set +e; eval "$TEST_CMD"; rc=$?; set -e
      if [ "$rc" -ne 0 ]; then BUILD_FAILED=1; fi
    fi
  else
    # Auto-detect from project files
    if [ -f "CMakeLists.txt" ] && command -v cmake &>/dev/null; then
      echo ""
      echo "=== Clean build + test (C++) ==="
      rm -rf build
      if cmake -B build && cmake --build build -j"$(nproc 2>/dev/null || echo 4)"; then
        if command -v ctest &>/dev/null; then
          if ! ctest --test-dir build --output-on-failure -j"$(nproc 2>/dev/null || echo 4)"; then
            BUILD_FAILED=1
          fi
        fi
      else
        BUILD_FAILED=1
      fi
    fi

    if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
      if command -v pytest &>/dev/null; then
        echo ""
        echo "=== Running tests (Python) ==="
        rc=0; pytest --tb=short -q || rc=$?
        # rc=0: passed, rc=5: no tests collected (all skipped) — both OK
        if [ "$rc" -ne 0 ] && [ "$rc" -ne 5 ]; then
          BUILD_FAILED=1
        fi
      fi
    fi
  fi

  if [ "$BUILD_FAILED" -ne 0 ]; then
    echo ""
    echo "Push blocked: build or tests failed."
    exit 1
  fi
fi

# ============================================================
# Step 3: Remaining issues (warn and continue)
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
rm -f .devkit/.last-review

exit 0
