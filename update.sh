#!/bin/bash
# Non-interactive update of dev-standards files in the current project.
# Run from project root, or via /update-dev-standards in Claude.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  dev-standards update"
echo "  ─────────────────────"
echo ""

# Pull latest submodule
echo "  Pulling latest submodule..."
git submodule update --remote .dev-standards
echo ""

# Slash commands (always overwrite)
echo "  Updating commands..."
mkdir -p .claude/commands
cp "$SCRIPT_DIR/commands/"*.md .claude/commands/

# AGENTS.md symlink
ln -sf CLAUDE.md AGENTS.md

# Git hooks
echo "  Updating git hooks..."
cp "$SCRIPT_DIR/hooks/pre-push.sh" .git/hooks/pre-push
chmod +x .git/hooks/pre-push
cp "$SCRIPT_DIR/hooks/commit-msg.sh" .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg

# Settings
echo "  Updating .claude/settings.json..."
cp "$SCRIPT_DIR/templates/settings.json.template" .claude/settings.json

echo ""
echo "  Update complete."
echo "  Note: CLAUDE.md was not modified (update manually if needed)."
echo ""
