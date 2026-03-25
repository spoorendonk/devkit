# dev-standards

Shared development standards, hooks, and tooling for Claude Code projects. Added as a git submodule to each project, it provides a consistent workflow across C++, Python, and C++/Python (nanobind) codebases.

## What's included

| Directory     | Contents                                                                 |
|---------------|--------------------------------------------------------------------------|
| `standards/`  | Coding standards (common workflow, C++, Python, nanobind)                |
| `templates/`  | `CLAUDE.md` templates and `settings.json` for Claude Code               |
| `commands/`   | Slash commands (`/start`, `/review`)                                     |
| `hooks/`      | Git hooks (commit-msg, pre-push) and Claude Code hooks                  |
| `config/`     | Shared tool configs (`.clang-format`, `.clang-tidy`, `pyproject.toml`)  |
| `statusline.sh` | Claude Code status line showing branch, review state, context usage  |
| `setup.sh`    | Interactive installer                                                    |

## Setup

### Add to an existing project

From your project's root directory, add the submodule and run setup:

```bash
git submodule add git@github.com:flowty/dev-standards.git .dev-standards
.dev-standards/setup.sh
```

> **Note:** The setup script also adds the submodule if `.dev-standards/` doesn't exist yet, so you can run `setup.sh` directly if you've already cloned the repo locally. But the above is the standard approach.

### Cloning a project that already uses dev-standards

When you clone a repo that has dev-standards as a submodule, the `.dev-standards/` directory will be empty by default. Initialize it with:

```bash
git clone <your-repo-url>
cd <your-repo>
git submodule update --init
```

Or clone with submodules in one step:

```bash
git clone --recurse-submodules <your-repo-url>
```

The setup script will:

1. Ask for your project name and type (C++, Python, or C++/Python)
2. Add `dev-standards` as a git submodule at `.dev-standards/`
3. Generate a `CLAUDE.md` from the appropriate template
4. Copy `.claude/settings.json` with pre-configured permissions and hooks
5. Copy slash commands (`/start`, `/review`) into `.claude/commands/`
6. Install git hooks (`commit-msg`, `pre-push`)
7. Symlink tool configs (`.clang-format`, `.clang-tidy`) for C++ projects
8. Copy `pyproject.toml` with ruff/mypy config for Python projects

If files already exist, the script shows a diff and lets you choose to overwrite, view the full diff, or skip.

### After setup

```bash
# 1. Open Claude Code in the project
claude

# 2. Run /init to auto-detect project details and fill out CLAUDE.md
/init

# 3. Commit the scaffolding
git add CLAUDE.md .claude/ .dev-standards .gitmodules
git commit -m "chore: add dev-standards"

# 4. Start working
/start
```

### Updating

Pull the latest standards into an existing project:

```bash
cd .dev-standards && git pull origin main && cd ..
git add .dev-standards
git commit -m "chore: update dev-standards"
```

Then re-run `setup.sh` to pick up any new hooks or commands.

## Workflow

```
/start → plan (non-trivial) → implement → test → /review → push to main
```

- **`/start`** — Checks branch state, flags stale branches, lets you pick or create a branch.
- **Plan** — For non-trivial work, enter plan mode and align on approach before coding.
- **Implement** — Write code. Hooks auto-format and type-check on every save.
- **Test** — Run tests locally.
- **`/review`** — Multi-agent review pipeline. Nits are auto-fixed; major issues are presented for decision.
- **Push** — Pre-push hook runs tests, linters, and checks review status.

### Git conventions

- Trunk-based development with linear history on main (no PRs, no merge commits).
- Always branch from main. Keep branches short-lived.
- Conventional Commits enforced by the `commit-msg` hook.

## Hooks

### Git hooks

| Hook         | What it does                                                                 |
|--------------|------------------------------------------------------------------------------|
| `commit-msg` | Validates Conventional Commits format, enforces 72-char subject line         |
| `pre-push`   | Auto-formats, runs tests (hard block), checks review status, runs linters    |

### Claude Code hooks

| Hook                    | Trigger          | What it does                                             |
|-------------------------|------------------|----------------------------------------------------------|
| `post-tool-format.sh`   | Write/Edit       | Auto-formats saved files, checks complexity and types    |
| `check-branch-create.sh`| Bash (pre)       | Blocks branch creation when not on main                  |
| `check-venv.sh`         | Bash (pre)       | Blocks bare `python`/`pip` if a venv exists but isn't active |
| `check-pending-review.sh`| Any (post)      | Reminds to run `/review` if one was requested            |

## Status line

The status line (configured in `settings.json`) shows at a glance:

- Current directory and session name
- Branch with ahead/behind indicators (color-coded)
- Number of local branches (stale ones highlighted)
- Review status (`ok`, `pending`, `none`, or commits behind)
- Context window remaining (color-coded)

## Project types

| Type          | Template               | Includes                                       |
|---------------|------------------------|-------------------------------------------------|
| C++           | `CLAUDE.md.cpp`        | C++ standards, `.clang-format`, `.clang-tidy`   |
| Python        | `CLAUDE.md.python`     | Python standards, `pyproject.toml`              |
| C++/Python    | `CLAUDE.md.cpp-python` | Nanobind standards, all of the above            |

All templates import the shared common standards (workflow, git, review, plan adherence).
