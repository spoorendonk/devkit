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

# Pull the submodule and re-exec self if the pull brought in a new update.sh.
# Without the re-exec, bash keeps running the old parsed-in-memory script body,
# so any new hook-install line or symlink-sync step added in the pulled range
# silently no-ops until the user runs update.sh a second time. DEVKIT_UPDATE_REEXECED
# guards against loops if the hash keeps changing for some reason.
if [ -z "${DEVKIT_UPDATE_REEXECED:-}" ]; then
  echo "  Pulling latest submodule..."
  UPDATE_SH_HASH_BEFORE=$(md5sum "$0" | awk '{print $1}')
  git submodule update --remote .devkit
  UPDATE_SH_HASH_AFTER=$(md5sum "$0" | awk '{print $1}')
  echo ""

  if [ "$UPDATE_SH_HASH_BEFORE" != "$UPDATE_SH_HASH_AFTER" ]; then
    echo "  update.sh changed in this pull — re-executing with new logic."
    echo ""
    export DEVKIT_UPDATE_REEXECED=1
    exec "$0" "$@"
  fi
fi

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

# Config symlinks: if the project has opted into devkit-shared configs (has at
# least one existing symlink into .devkit/config/, e.g. .clang-format from
# setup.sh), create symlinks for any new files devkit has added since setup
# (e.g. .clangd added later). Don't touch regular files or differently-targeted
# symlinks — those are the user's own customizations.
echo "  Syncing config symlinks..."
uses_devkit_config=0
for f in .*; do
  [ -L "$f" ] || continue
  case "$(readlink "$f")" in
    .devkit/config/*) uses_devkit_config=1; break ;;
  esac
done

if [ "$uses_devkit_config" = "1" ]; then
  for cfg in "$SCRIPT_DIR/config/".*; do
    [ -f "$cfg" ] || continue
    name=$(basename "$cfg")
    case "$name" in
      .|..|*.template) continue ;;
    esac
    if [ ! -e "$name" ] && [ ! -L "$name" ]; then
      ln -s ".devkit/config/$name" "$name"
      echo "    linked $name -> .devkit/config/$name"
    fi
  done
fi

# Git hooks
echo "  Updating git hooks..."
# resolve-venv.sh is a helper sourced by pre-commit.sh, pre-push.sh and
# post-tool-format.sh; install it alongside so `source $(dirname $0)/resolve-venv.sh` works.
install_hook resolve-venv.sh resolve-venv.sh
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
