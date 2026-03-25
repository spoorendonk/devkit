#!/bin/bash
# Interactive setup script for dev-standards.
# Run from a project repo root.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Helper: show diff and ask whether to overwrite, skip, or show diff
# Usage: offer_file <source> <destination> <description>
offer_file() {
  local src="$1"
  local dst="$2"
  local desc="$3"

  if [ ! -f "$dst" ]; then
    echo "  Creating $desc..."
    return 0  # caller should create the file
  fi

  # File exists — check if identical
  if diff -q "$src" "$dst" &>/dev/null; then
    echo "  $desc: already up to date."
    return 1  # caller should skip
  fi

  # File exists and differs
  echo ""
  echo "  $desc already exists and differs from template:"
  echo "  ─────────────────────────────────────────────────"
  diff --color=auto -u "$dst" "$src" | head -40 || true
  echo "  ─────────────────────────────────────────────────"
  echo ""
  echo "  [o] Overwrite with template"
  echo "  [d] Show full diff"
  echo "  [s] Skip (keep existing)"
  echo ""

  while true; do
    read -p "  > " -r -n1 CHOICE
    echo ""
    case "$CHOICE" in
      o|O)
        echo "  Overwriting $desc..."
        return 0
        ;;
      d|D)
        diff --color=auto -u "$dst" "$src" || true
        echo ""
        echo "  [o] Overwrite  [s] Skip"
        ;;
      s|S)
        echo "  Keeping existing $desc."
        return 1
        ;;
      *)
        echo "  Invalid choice. Press o, d, or s."
        ;;
    esac
  done
}

echo ""
echo "  dev-standards setup"
echo "  ─────────────────────"
echo ""

# Check we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
  echo "Error: not in a git repository. Run this from a project repo root."
  exit 1
fi

# Project name
read -p "  Project name: " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  echo "Error: project name is required."
  exit 1
fi

# Project type
echo ""
echo "  Project type:"
echo "    1) C++"
echo "    2) Python"
echo "    3) C++/Python (nanobind)"
echo ""
read -p "  > " PROJECT_TYPE

case "$PROJECT_TYPE" in
  1) TEMPLATE="cpp" ;;
  2) TEMPLATE="python" ;;
  3) TEMPLATE="cpp-python" ;;
  *)
    echo "Error: invalid choice. Pick 1, 2, or 3."
    exit 1
    ;;
esac

echo ""

# Add submodule if not already present
if [ ! -d ".dev-standards" ]; then
  echo "  Adding submodule..."
  git submodule add git@github.com:flowty/dev-standards.git .dev-standards
else
  echo "  .dev-standards/ already exists, skipping submodule add."
fi

# Create .claude directory
mkdir -p .claude/commands

# Generate CLAUDE.md from template (with project name substituted)
CLAUDE_MD_TMP=$(mktemp)
sed "s/__PROJECT_NAME__/$PROJECT_NAME/g" \
  "$SCRIPT_DIR/templates/CLAUDE.md.$TEMPLATE.template" > "$CLAUDE_MD_TMP"

if offer_file "$CLAUDE_MD_TMP" "CLAUDE.md" "CLAUDE.md ($TEMPLATE)"; then
  cp "$CLAUDE_MD_TMP" CLAUDE.md
fi
rm -f "$CLAUDE_MD_TMP"

# settings.json
if offer_file "$SCRIPT_DIR/templates/settings.json.template" ".claude/settings.json" ".claude/settings.json"; then
  cp "$SCRIPT_DIR/templates/settings.json.template" .claude/settings.json
fi

# Symlink tool config files (C++ projects)
if [ "$TEMPLATE" = "cpp" ] || [ "$TEMPLATE" = "cpp-python" ]; then
  if [ ! -f ".clang-format" ]; then
    echo "  Symlinking .clang-format..."
    ln -s .dev-standards/config/.clang-format .clang-format
  elif [ -L ".clang-format" ]; then
    echo "  .clang-format: already a symlink."
  else
    echo ""
    echo "  .clang-format exists (not a symlink). Diff with shared config:"
    echo "  ─────────────────────────────────────────────────"
    diff --color=auto -u .clang-format "$SCRIPT_DIR/config/.clang-format" | head -30 || true
    echo "  ─────────────────────────────────────────────────"
    echo "  [o] Replace with symlink  [s] Keep existing"
    while true; do
      read -p "  > " -r -n1 CHOICE
      echo ""
      case "$CHOICE" in
        o|O) rm .clang-format; ln -s .dev-standards/config/.clang-format .clang-format; echo "  Replaced with symlink."; break ;;
        s|S) echo "  Keeping existing."; break ;;
        *) echo "  Press o or s." ;;
      esac
    done
  fi

  if [ ! -f ".clang-tidy" ]; then
    echo "  Symlinking .clang-tidy..."
    ln -s .dev-standards/config/.clang-tidy .clang-tidy
  elif [ -L ".clang-tidy" ]; then
    echo "  .clang-tidy: already a symlink."
  else
    echo ""
    echo "  .clang-tidy exists (not a symlink). Diff with shared config:"
    echo "  ─────────────────────────────────────────────────"
    diff --color=auto -u .clang-tidy "$SCRIPT_DIR/config/.clang-tidy" | head -30 || true
    echo "  ─────────────────────────────────────────────────"
    echo "  [o] Replace with symlink  [s] Keep existing"
    while true; do
      read -p "  > " -r -n1 CHOICE
      echo ""
      case "$CHOICE" in
        o|O) rm .clang-tidy; ln -s .dev-standards/config/.clang-tidy .clang-tidy; echo "  Replaced with symlink."; break ;;
        s|S) echo "  Keeping existing."; break ;;
        *) echo "  Press o or s." ;;
      esac
    done
  fi
fi

# Python config (pyproject.toml)
if [ "$TEMPLATE" = "python" ] || [ "$TEMPLATE" = "cpp-python" ]; then
  if offer_file "$SCRIPT_DIR/config/pyproject.toml.template" "pyproject.toml" "pyproject.toml"; then
    cp "$SCRIPT_DIR/config/pyproject.toml.template" pyproject.toml
  fi
fi

# Copy commands (always update to latest)
echo "  Updating commands (start, review)..."
cp "$SCRIPT_DIR/commands/"*.md .claude/commands/

# Git hooks
if offer_file "$SCRIPT_DIR/hooks/pre-push.sh" ".git/hooks/pre-push" ".git/hooks/pre-push"; then
  cp "$SCRIPT_DIR/hooks/pre-push.sh" .git/hooks/pre-push
  chmod +x .git/hooks/pre-push
fi

if offer_file "$SCRIPT_DIR/hooks/commit-msg.sh" ".git/hooks/commit-msg" ".git/hooks/commit-msg"; then
  cp "$SCRIPT_DIR/hooks/commit-msg.sh" .git/hooks/commit-msg
  chmod +x .git/hooks/commit-msg
fi

echo ""
echo "  Done. Next steps:"
echo "    1. Open a Claude Code session in this project"
echo "    2. Run /init to auto-detect project details and flesh out CLAUDE.md"
echo "    3. Commit: git add CLAUDE.md .claude/ .dev-standards .gitmodules"
echo "    4. Run /start to begin your first session"
echo ""
