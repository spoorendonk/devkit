#!/bin/bash
# Non-interactive update of dev-standards files in the current project.
# Run from project root, or via /update-dev-standards in Claude.

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
