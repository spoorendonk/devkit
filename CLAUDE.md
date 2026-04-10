# devkit

**This is the devkit source repo.** It is the upstream for a set of shared dev standards, git hooks, Claude Code hooks, slash commands, templates, and setup/update scripts that downstream C++/Python projects consume by adding this repo as a git submodule at `.devkit/`.

Nothing in this repo is "applied" to itself the way it would be in a consumer project — the `@.devkit/...` imports in `standards/` and `templates/` are written for downstream projects where devkit lives at that submodule path. In *this* repo, devkit lives at the root, and the paths are only meaningful as the content that gets handed to consumers.

## Layout

- `commands/` — slash command sources (`review.md`). Downstream projects get these as symlinks in `.claude/commands/`.
- `hooks/` — git hooks (`pre-commit.sh`, `pre-push.sh`, `commit-msg.sh`), Claude Code hooks (`post-tool-format.sh`, `check-branch-create.sh`, `check-venv.sh`), and a shared helper (`resolve-venv.sh`) sourced by several of the above.
- `standards/` — coding standards (`common.md`, `cpp.md`, `python.md`, `nanobind.md`). `cpp.md` and `python.md` import `@common.md`; `nanobind.md` imports both. Language templates in `templates/CLAUDE.md.*.template` import from `@.devkit/standards/` — that path resolves correctly in downstream projects, not here.
- `templates/` — `CLAUDE.md` templates (one per project type) and `settings.json.template` copied/merged into downstream projects at setup time.
- `config/` — shared tool configs (`.clang-format`, `.clang-tidy`, `pyproject.toml.template`).
- `setup.sh` — interactive installer that bootstraps a new consumer project (adds submodule, generates CLAUDE.md from template, installs hooks, symlinks commands, merges `pyproject.toml`).
- `update.sh` — non-interactive updater for existing consumer projects (refreshes command symlinks, reinstalls hooks, jq-merges `settings.json`).
- `statusline.sh` — Claude Code statusline script.

## How a consumer project uses this

```
consumer-project/
  .devkit/            # git submodule → this repo
    standards/common.md
    hooks/pre-push.sh
    ...
  .claude/
    settings.json     # copied/merged from templates/settings.json.template
    commands/
      review.md       # symlink → ../../.devkit/commands/review.md
  CLAUDE.md           # generated from templates/CLAUDE.md.<type>.template, imports @.devkit/standards/<type>.md
  .git/hooks/
    pre-push          # copied from .devkit/hooks/pre-push.sh
    ...
```

`setup.sh` creates this layout on first run; `update.sh` refreshes it without re-prompting.

## Build & test

No build. Syntax-check the shell scripts:

```test
for f in setup.sh update.sh statusline.sh hooks/*.sh; do bash -n "$f" || exit 1; done
```

The `pyproject.toml` merge logic in `setup.sh` has non-trivial semantics. When changing it, verify against a realistic fixture in `/tmp` and parse with `python3 -c "import tomllib; tomllib.load(open('pyproject.toml','rb'))"`. Cover idempotency (re-run 3 times, hash should be stable) and TOML array-of-tables (`[[tool.mypy.overrides]]` must survive the merge — devkit does not own array-of-tables, only single-bracket `[tool.ruff*]` and `[tool.mypy*]`).

## When editing this repo

- **Adding/removing a slash command.** Create or delete a file in `commands/`. `setup.sh` and `update.sh` both loop over `commands/*.md`, and both prune orphaned symlinks in downstream projects. No script edits needed.
- **Adding a git hook.** Both `setup.sh` and `update.sh` hardcode the install list via `install_hook` calls. Update both.
- **Extending the `pyproject.toml` merge.** The awk regex in `setup.sh` currently owns `[tool.ruff*]` and `[tool.mypy*]` (single-bracket). If `config/pyproject.toml.template` grows a new `[tool.X]` section, extend the regex. A `NOTE` comment at the merge block points at this.
- **Editing `templates/settings.json.template`.** `update.sh` uses `jq` to union `permissions.allow`/`deny` and merge `hooks` by matcher (template wins on matcher collisions, user-only entries preserved). Reason about this merge behavior when changing the template.
- **`.claude/settings.json` in this repo diverges from the template.** It uses repo-root paths (`bash hooks/post-tool-format.sh`) instead of `.devkit/hooks/...` because this repo is self-hosted. Do not sync it from `templates/settings.json.template`.
- **`.claude/commands/review.md` is a symlink** to `../../commands/review.md`. Edit `commands/review.md` directly.

## Testing a change end-to-end against a real consumer

For non-trivial setup/update changes, run against a scratch consumer project:

```bash
mkdir /tmp/devkit-smoketest && cd /tmp/devkit-smoketest
git init && echo "scratch" > README.md && git add . && git commit -m "init"
git submodule add /home/simon/code/my/devkit .devkit
.devkit/setup.sh   # pick project type, walk the prompts
# then: inspect generated CLAUDE.md, .claude/, .git/hooks/, pyproject.toml
```
