#!/bin/bash
# Non-interactive update of devkit files in the current project.
# Run from project root, or via /update-devkit in Claude.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Helper: install a git hook (overwrites silently — this is a non-interactive update)
install_hook() {
  local hook="$1"
  local src="$SCRIPT_DIR/hooks/$2"
  local dst=".git/hooks/$hook"

  cp "$src" "$dst"
  chmod +x "$dst"
}

echo ""
echo "  devkit update"
echo "  ─────────────────────"
echo ""

# Pull latest submodule
echo "  Pulling latest submodule..."
git submodule update --remote .devkit
echo ""

# Slash commands (symlink to submodule)
echo "  Updating command symlinks..."
mkdir -p .claude/commands

# Prune symlinks for commands no longer in devkit (e.g. start.md after removal)
for link in .claude/commands/*.md; do
  [ -L "$link" ] && [ ! -e "$link" ] && rm "$link"
done

for cmd in "$SCRIPT_DIR/commands/"*.md; do
  name=$(basename "$cmd")
  rm -f ".claude/commands/$name"
  ln -s "../../.devkit/commands/$name" ".claude/commands/$name"
done

# AGENTS.md symlink
ln -sf CLAUDE.md AGENTS.md

# Git hooks
echo "  Updating git hooks..."
install_hook pre-commit pre-commit.sh
install_hook pre-push pre-push.sh
install_hook commit-msg commit-msg.sh

# Settings (merge: template defaults + user additions preserved)
echo "  Merging .claude/settings.json..."
TEMPLATE="$SCRIPT_DIR/templates/settings.json.template"
CURRENT=".claude/settings.json"

if [ ! -f "$CURRENT" ]; then
  cp "$TEMPLATE" "$CURRENT"
elif command -v jq &>/dev/null; then
  # Merge permissions arrays (union, deduplicated)
  # Merge hooks (template entries win by matcher, user-only entries preserved)
  # Other keys: template as base, user overrides on top
  MERGED=$(jq -s '
    .[0] as $tpl | .[1] as $usr |

    # Start with template, overlay user keys
    ($tpl * $usr) |

    # Union permissions.allow and .deny arrays
    .permissions.allow = (($tpl.permissions.allow // []) + ($usr.permissions.allow // []) | unique) |
    .permissions.deny = (($tpl.permissions.deny // []) + ($usr.permissions.deny // []) | unique) |

    # Merge hooks: for each event, combine by matcher (template wins for same matcher, user-only matchers kept)
    .hooks = (
      ($tpl.hooks // {} | keys) + ($usr.hooks // {} | keys) | unique | map(. as $evt |
        {
          ($evt): (
            (($tpl.hooks[$evt] // []) | map({key: (.matcher // ""), value: .})) as $tpl_hooks |
            (($usr.hooks[$evt] // []) | map({key: (.matcher // ""), value: .})) as $usr_hooks |
            # Template entries, then user entries with matchers not in template
            ($tpl_hooks | map(.value)) +
            ($usr_hooks | map(select(.key as $k | $tpl_hooks | map(.key) | index($k) | not)) | map(.value))
          )
        }
      ) | add
    )
  ' "$TEMPLATE" "$CURRENT") && echo "$MERGED" | jq . > "$CURRENT"
else
  echo "  Warning: jq not found, skipping settings merge."
fi

echo ""
echo "  Update complete."
echo "  Note: CLAUDE.md was not modified (update manually if needed)."
echo ""
