#!/bin/bash
# Interactive setup script for devkit.
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

# Helper: offer to install a git hook
# Usage: install_hook <hook-name> <source-filename>
install_hook() {
  local hook="$1"
  local src="$SCRIPT_DIR/hooks/$2"
  local dst=".git/hooks/$hook"

  if offer_file "$src" "$dst" ".git/hooks/$hook"; then
    cp "$src" "$dst"
    chmod +x "$dst"
  fi
}

# Helper: offer to symlink a config file from .devkit
# Usage: offer_symlink <filename> <config-subpath>
offer_symlink() {
  local name="$1"
  local target=".devkit/config/$1"

  if [ ! -f "$name" ]; then
    echo "  Symlinking $name..."
    ln -s "$target" "$name"
  elif [ -L "$name" ]; then
    echo "  $name: already a symlink."
  else
    echo ""
    echo "  $name exists (not a symlink). Diff with shared config:"
    echo "  ─────────────────────────────────────────────────"
    diff --color=auto -u "$name" "$SCRIPT_DIR/config/$name" | head -30 || true
    echo "  ─────────────────────────────────────────────────"
    echo "  [o] Replace with symlink  [s] Keep existing"
    while true; do
      read -p "  > " -r -n1 CHOICE
      echo ""
      case "$CHOICE" in
        o|O) rm "$name"; ln -s "$target" "$name"; echo "  Replaced with symlink."; break ;;
        s|S) echo "  Keeping existing."; break ;;
        *) echo "  Press o or s." ;;
      esac
    done
  fi
}

echo ""
echo "  devkit setup"
echo "  ─────────────────────"
echo ""

# Check we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
  echo "Error: not in a git repository. Run this from a project repo root."
  exit 1
fi

# Project name (default to current directory/repo name)
DEFAULT_PROJECT_NAME=$(basename "$(pwd)")
read -p "  Project name [$DEFAULT_PROJECT_NAME]: " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"

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
if [ ! -d ".devkit" ]; then
  echo "  Adding submodule..."
  git submodule add https://github.com/flowty/devkit.git .devkit
else
  echo "  .devkit/ already exists, skipping submodule add."
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

# AGENTS.md symlink for other AI tools (Codex, Cursor, Copilot)
ln -sf CLAUDE.md AGENTS.md

# settings.json
if offer_file "$SCRIPT_DIR/templates/settings.json.template" ".claude/settings.json" ".claude/settings.json"; then
  cp "$SCRIPT_DIR/templates/settings.json.template" .claude/settings.json
fi

# Symlink tool config files (C++ projects)
if [ "$TEMPLATE" = "cpp" ] || [ "$TEMPLATE" = "cpp-python" ]; then
  offer_symlink .clang-format
  offer_symlink .clang-tidy
fi

# Python config (pyproject.toml)
if [ "$TEMPLATE" = "python" ] || [ "$TEMPLATE" = "cpp-python" ]; then
  if offer_file "$SCRIPT_DIR/config/pyproject.toml.template" "pyproject.toml" "pyproject.toml"; then
    cp "$SCRIPT_DIR/config/pyproject.toml.template" pyproject.toml
  fi
fi

# Symlink commands (always update to latest)
echo "  Symlinking commands (start, review)..."
for cmd in "$SCRIPT_DIR/commands/"*.md; do
  name=$(basename "$cmd")
  target="../../.devkit/commands/$name"
  dst=".claude/commands/$name"
  if [ -L "$dst" ]; then
    echo "    $name: already a symlink."
  else
    rm -f "$dst"
    ln -s "$target" "$dst"
  fi
done

# Git hooks
install_hook pre-commit pre-commit.sh
install_hook pre-push pre-push.sh
install_hook commit-msg commit-msg.sh

echo ""
echo "  Done. Next steps:"
echo "    1. Open a Claude Code session in this project"
echo "    2. Run /init to auto-detect project details and flesh out CLAUDE.md"
echo "    3. Commit: git add CLAUDE.md AGENTS.md .claude/ .devkit .gitmodules"
echo "    4. Run /start to begin your first session"
echo ""
