## Communication Style

Be terse. No preamble. No filler.

## Development Workflow

```
plan (non-trivial) → implement → test → /review → push to main
```

Hooks auto-format and type-check on save — don't fix formatting manually. Run tests locally before considering work done — don't skip the suite even on changes that look trivial. The pre-push hook is the final gate.

## Git Workflow

Trunk-based development with linear history on main. Commit directly to main and push when local gates pass.

Feature branches are optional for larger changes:
- Always branch from main. Run `git checkout main && git pull` first.
- Never branch from another feature branch.
- Keep branches short-lived; rebase or squash merge — no merge commits on main.

After a successful push:
- **Close any gh issue the work resolved**: `gh issue close <num> -c "<one-line note>"`. Do this for every issue covered by the push.
- **Delete the feature branch** if one was used: `git branch -d <branch>` locally, plus `git push origin --delete <branch>` if it was pushed. Don't leave stale branches behind.

## Hooks Are Upstream

Git hooks (`.git/hooks/*`, installed from `.devkit/hooks/`) and Claude Code hooks (entries in `.claude/settings.json`) come from devkit and are treated as fixed. The real source is upstream in the devkit submodule.

- **Don't edit installed hooks in-project to work around a failure.** If a hook is wrong or too strict, raise it as an upstream devkit issue. Local edits will be overwritten on the next `setup.sh`/`update.sh`.
- **Never use `git push --no-verify` or `git commit --no-verify`** unless explicitly asked. A failing hook is a signal — fix the root cause or escalate upstream.

## Issue Tracking

GitHub Issues is the tracker. Use the `gh` CLI.

- **Default to HTTPS** for GitHub remotes (`https://github.com/...`), not SSH.
- **Read an issue** with `gh issue view <num> --json title,body,labels,state,comments`. Plain `gh issue view <num>` is deprecated for programmatic use.
- Don't propose deferring work via a new gh issue unless it is substantial. Small follow-ups should be either fixed inline or left alone — don't open an issue just because you noticed something.

### Writing Issues

Issues get picked up later in fresh sessions, often by a different agent with no access to the author's machine. Write them to be picked up cold:

- **Self-contained.** Body must carry all needed context: problem, motivation, acceptance criteria, repro steps. Don't assume the reader has the current conversation.
- **No local references.** No local file paths, local repo paths, or machine-specific locations (`/home/user/...`, `~/code/foo/bar.py`, "see my other checkout"). Dead links in a fresh session.
- **Prefer stable external links.** GitHub permalinks, paper URLs, RFCs, official docs.
- **Be vague about local code context.** Describe the concept rather than the path; hint that the agent can search under `..`, `../..`, or `~/code/`.

## Agent Self-Review

**Any agent or agent team that produces code must run `/review` on its own changes before that code can merge to main.** No subagent returns unreviewed work; no orchestrator merges unreviewed work. This applies to every agent team, not just the parallel-issue workflow.

## Parallel Issue Workflow

When the user brings multiple gh issues to work on at once:

1. **Propose parallelism first.** Offer it explicitly and wait for confirmation — don't silently start serial work.
2. **Orchestrator role.** Spawn one subagent per issue (Agent tool with `isolation: "worktree"`). Subagents branch from main, not from the orchestrator's working branch, and work in their own git worktree. Pass each subagent its gh issue number and any plan file path.
3. **Subagents self-review** per the Agent Self-Review rule above. Subagents commit locally in their worktree and **do not push** — worktrees share `.git`, so the orchestrator sees their commits via `git log <branch>` with no network round-trip.
4. **No merging without user OK.** Subagents never merge into main; the orchestrator never merges a subagent's branch without explicit user approval.
5. **Final combined review, then push.** The orchestrator merges all approved branches into local main, runs `/review` over the merged result, and only then runs `git push origin main`. No pushes — of main or feature branches — happen before that final review.

## Commit Messages

Conventional Commits. The commit-msg hook enforces format.

- `type: description` or `type(scope): description`
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `perf`, `chore`, `build`, `ci`
- Subject ≤72 chars. Focus on **why**, not what.

## CLAUDE.md Discipline

When Claude gets something wrong, fix CLAUDE.md in the same commit. It's a living document — update it whenever better instructions would have prevented the mistake.

## Complexity

When a complexity warning fires, don't extract methods mechanically. Ask: what are the independent responsibilities here? Split along those boundaries. If the function is genuinely complex because the domain is, add a comment explaining why and suppress the warning.

## Plan Adherence

**Follow the agreed plan.** If you think a plan should change, stop and discuss — don't silently diverge. The same goes outside a written plan: if your current approach isn't working, say so out loud — don't quietly switch strategies. Implement everything specified; don't leave TODO placeholders or stub implementations unless explicitly asked.

## Reference Correctness

When implementing from papers, pseudocode, or open-source references:
- Match the reference algorithm exactly. No early exits, iteration limits, size caps, or "optimization" shortcuts that change behavior.
- Only introduce heuristic approximations when explicitly asked.
- Implement edge cases and special handling — don't simplify them away.
- When in doubt, be faithful to the reference and let tests verify correctness.

## Common Mistakes

- **Don't invent APIs — verify they exist.** Check that functions, flags, and methods actually exist before using them.
- **Don't ignore type errors.** If mypy/clang-tidy flags something, fix the root cause — don't suppress.
- **Don't use deprecated patterns.** Check current docs, not training data.
- **Performance matters.** Most of our code is solvers — profile before micro-optimizing, but don't sacrifice perf for "clean code".
