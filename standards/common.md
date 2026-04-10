## Development Workflow

```
plan (non-trivial) → implement → test → /review → push to main
```

1. **Plan**: for non-trivial work, enter plan mode and align on approach before implementing. Small fixes can go straight to code.
2. **Implement**: write code. Hooks auto-format, type-check, and flag complexity on every save.
3. **Test**: run tests locally before considering work done.
4. **`/review`**: multi-agent review pipeline. Nits are auto-fixed. Major issues are presented for human decision.
5. **Push to main**: pre-push hook is the final gate (tests + clang-tidy + mypy).

## Git Workflow

Trunk-based development with linear history on main. Commit directly to main and push when local gates (pre-push hooks) pass.

Feature branches are optional for larger changes:
- Always branch from main. Run `git checkout main && git pull` before creating a branch.
- Never create a branch from another feature branch.
- Keep branches short-lived. Merge to main quickly.
- Use rebase or squash merge to maintain linear history — no merge commits on main.

## Hooks Are Upstream

Git hooks (`.git/hooks/*`, installed from `.devkit/hooks/`) and Claude Code hooks (entries in `.claude/settings.json`) are installed by devkit and treated as fixed. The real source lives upstream in the devkit submodule.

- **Don't edit installed hooks in-project to work around a failure.** If a hook is wrong or too strict, raise it as a question or gh issue so the fix lands upstream in devkit and propagates to all projects. Local edits will be overwritten the next time `setup.sh` or `update.sh` runs.
- **Never use `git push --no-verify` or `git commit --no-verify`** to bypass hooks unless the user explicitly asks for it. A failing hook is a signal — investigate and fix the root cause. If the hook itself is the problem, treat it as an upstream devkit issue, not something to silence locally.

## Issue Tracking

GitHub Issues is the tracker. Use the `gh` CLI.

- **Default to HTTPS** for GitHub remotes and clones (`https://github.com/...`), not SSH.
- **Read an issue** with:
  ```bash
  gh issue view <num> --json title,body,labels,state,comments
  ```
  Plain `gh issue view <num>` is deprecated for programmatic use — always pass `--json` with the fields you need so output is stable and parseable.
- When work is deferred or out of scope, **open a new gh issue** rather than leaving a TODO in code.

### Writing Issues

Issues get picked up later in fresh sessions, often by a different agent with no access to the author's machine. Write them to be picked up cold:

- **Self-contained.** The body must carry all the context an agent needs: problem statement, motivation, relevant background, acceptance criteria, and reproduction steps if applicable. Don't assume the reader has the current conversation.
- **No local references.** Do not link to local file paths, local code repos, or machine-specific locations (e.g. `/home/user/...`, `~/code/foo/bar.py`, "see my other checkout"). These are dead links in a fresh session.
- **Prefer stable external links.** GitHub permalinks (repo/file/line), paper URLs, RFCs, and official docs are durable and reviewable from anywhere.
- **Be vague about local code context.** If related work lives in a nearby local repo, describe the concept rather than the path, and hint that the agent can search under `..`, `../..`, or `~/code/` to locate it.

## Parallel Issue Workflow

When the user brings multiple gh issues to work on at once:

1. **Propose parallelism first.** Don't silently start serial work — offer to run the issues in parallel and wait for user confirmation.
2. **Orchestrator role.** Once approved, act as the orchestrator: spawn one subagent per issue (Agent tool). The orchestrator tracks progress and coordinates. Subagents branch from main, not from the orchestrator's working branch. The orchestrator passes each subagent the relevant gh issue number and any plan file path so the subagent has full context.
3. **Subagents self-review.** Each subagent runs its own `/review` pass on its own changes before returning results. A subagent never returns unreviewed work.
4. **No merging without user OK.** Subagents never merge their branches into main, and the orchestrator never merges a subagent's branch, before the user has explicitly approved it.
5. **Final review covers the merged whole.** After all subagent branches are merged, the orchestrator runs a **complete review over the merged code** covering every subagent's contribution. No `git push` happens until that final combined review is done.

## Commit Messages

Use Conventional Commits. The commit-msg hook enforces the format.

- Format: `type: description` or `type(scope): description`
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `perf`, `chore`, `build`, `ci`
- Subject line max 72 characters. Focus on **why**, not what (the diff shows what).

## CLAUDE.md Discipline

- When Claude gets something wrong, fix CLAUDE.md in the same commit — this is the core feedback loop.
- CLAUDE.md is a living document. Update it whenever Claude makes a mistake that better instructions would prevent.

## Code Review

- Use `/review` before pushing to run the multi-agent review pipeline.
- Review findings are categorized as nits (auto-fixed) or major (requires human decision).

## Complexity

When a complexity warning fires, don't just extract methods mechanically.
Ask: what are the independent responsibilities here? Split along those
boundaries. If the function is genuinely complex because the domain is
complex, add a comment explaining why and suppress the warning.

## Plan Adherence

- Follow the agreed plan exactly. Do not take shortcuts, skip steps, or defer work without explicit permission.
- If you think the plan should change, stop and discuss — don't silently diverge.
- Implement everything specified in the plan. Do not leave TODO placeholders or stub implementations unless explicitly asked.

## Reference Correctness

When implementing from papers, pseudocode, or open-source references:
- Match the reference algorithm exactly. Do not add early exits, iteration limits, size caps, or "optimization" shortcuts that change the algorithm's behavior.
- Only introduce heuristic approximations when explicitly asked to do so.
- If the reference has edge cases or special handling, implement them — don't simplify them away.
- When in doubt, be faithful to the reference and let tests verify correctness.

## Common Mistakes

Lessons from recurring Claude errors. When you catch a new pattern, add it here.

### Behavioral
- **Don't add unrequested features.** If the user asked for X, deliver X — not X plus "helpful" extras.
- **Don't refactor surrounding code.** A bug fix doesn't need adjacent code cleaned up.
- **Don't skip tests to move faster.** Run the test suite even when changes seem trivial.
- **Don't silently change approach.** If something isn't working, say so — don't quietly try a different strategy.

### Technical
- **Don't invent APIs — verify they exist.** Check that functions, flags, and methods actually exist before using them.
- **Don't ignore type errors.** If mypy/clang-tidy flags something, fix the root cause — don't suppress or work around it.
- **Don't use deprecated patterns.** Check current docs, not training data. Prefer modern idioms.
- **Read before writing.** Always read a file before modifying it. Don't guess at existing code structure.

## General Principles

- Don't over-engineer. Avoid unnecessary abstractions, features, or error handling beyond what's needed.
- Three similar lines of code is better than a premature abstraction.
- Performance matters. Don't sacrifice it for "clean code" — but don't micro-optimize prematurely either. Profile first.
- Only add comments where the logic isn't self-evident.
