@standards/common.md

# devkit

Source of truth for shared dev standards, git hooks, Claude Code hooks, slash commands, and setup/update scripts. Consumed by downstream C++/Python projects as a git submodule at `.devkit/`.

## This repo is self-hosted

devkit dogfoods its own hooks and commands **from repo-root paths**, not from a `.devkit/` submodule. Keep this in mind:

- `.claude/settings.json` uses `bash hooks/post-tool-format.sh` (and friends), while `templates/settings.json.template` uses `bash .devkit/hooks/...`. The divergence is intentional — do NOT sync `.claude/settings.json` from the template.
- `.claude/commands/review.md` is a symlink to `../../commands/review.md`. Edit `commands/review.md`, not the symlink.
- `CLAUDE.md` imports `@standards/common.md` at the repo root, not `@.devkit/standards/...`.
- `.devkit/.last-review` lives at `.devkit/` as an ordinary directory here, not a submodule. It's gitignored.

## Build & test

No build. Tests are syntax checks plus manual scratch-dir runs for the tricky bits.

```test
for f in setup.sh update.sh statusline.sh hooks/*.sh; do bash -n "$f" || exit 1; done
```

For the `pyproject.toml` merge logic in `setup.sh`, verify changes against a realistic fixture in `/tmp` and parse with `python3 -c "import tomllib; tomllib.load(open('pyproject.toml','rb'))"`. Cover idempotency (re-run the merge 3 times, hash should be stable) and TOML array-of-tables (`[[tool.mypy.overrides]]` must survive the merge).

## Maintenance notes

- **Adding/removing slash commands.** Create/delete files in `commands/`. Both `setup.sh` and `update.sh` loop over `commands/*.md` automatically, and an orphan-symlink prune step removes stale symlinks from downstream projects.
- **Adding git hooks.** Both `setup.sh` and `update.sh` hardcode hook names in `install_hook` calls — update both when adding one.
- **Extending the `pyproject.toml` merge.** The awk regex in `setup.sh` currently owns `[tool.ruff*]` and `[tool.mypy*]` (single-bracket only; array-of-tables are intentionally preserved). If `config/pyproject.toml.template` grows a new `[tool.X]` section, extend the regex — there's a NOTE comment at the merge block.
- **Settings merge behavior.** `update.sh` uses `jq` to union `permissions.allow`/`deny` and merge `hooks` by matcher. Template entries win on matcher conflicts; user-only entries are preserved.

## Review stamping

`.devkit/.last-review` records the HEAD hash that `/review` last approved. It becomes stale whenever HEAD advances (commit, rebase, fast-forward). Re-stamp after each move with `git rev-parse HEAD > .devkit/.last-review` or `/review --stamp`.
