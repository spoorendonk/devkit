## Development Workflow

```
/start → plan (non-trivial) → implement → test → /review → push to main
```

1. **`/start`**: check branch state, flag stale branches, pick or create a branch.
2. **Plan**: for non-trivial work, enter plan mode and align on approach before implementing. Small fixes can go straight to code.
3. **Implement**: write code. Hooks auto-format, type-check, and flag complexity on every save.
4. **Test**: run tests locally before considering work done.
5. **`/review`**: multi-agent review pipeline. Nits are auto-fixed. Major issues are presented for human decision.
6. **Push to main**: pre-push hook is the final gate (tests + clang-tidy + mypy).

## Git Workflow

Trunk-based development with linear history on main. Commit directly to main and push when local gates (pre-push hooks) pass.

Feature branches are optional for larger changes:
- Always branch from main. Run `git checkout main && git pull` before creating a branch.
- Never create a branch from another feature branch.
- Keep branches short-lived. Merge to main quickly.
- Use rebase or squash merge to maintain linear history — no merge commits on main.

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
