Run a multi-agent code review on all changes vs main. Follow these steps exactly.

## Options (from $ARGUMENTS)

- `--quick`: Do the review directly (no agents). Faster, less thorough.
- `--stamp`: Write current HEAD to the review stamp file (use when already reviewed manually). Jumps straight to Step 8.

## Step 1: Sync and determine diff base

`git fetch origin main` (or `master`). Then:

```bash
BRANCH=$(git symbolic-ref --short HEAD)
```

- **On main/master:** diff base is `origin/main` (review unpushed commits).
- **On a feature branch:** diff base is `main`. If `git rev-list --count main..origin/main` shows main is behind, tell the user and offer to update + rebase. Ask before doing anything. On approval: `git checkout main && git pull --ff-only origin main && git checkout <branch> && git rebase main`. Stop on rebase conflicts.

## Step 2: Gather the diff

`git diff <diff-base>...HEAD` for committed changes, plus `git diff` and `git diff --cached` for uncommitted. Combine into the full changeset. If empty, report and stop.

## Step 3: Read the standards

Read the project's standards files (those imported via `@.devkit/standards/` in CLAUDE.md).

## Step 4: Review

**If `--quick`:** Review yourself directly — no agents. Read full source files (not just the diff). Produce findings; skip to Step 6.

**Otherwise:** Launch **3** agents simultaneously. Each does a **full, independent review** of everything — they're not split by domain. Each agent receives:

- The full diff from Step 2
- The relevant source files (read full files for context, not just the diff)
- The standards from Step 3
- If linked to a gh issue: the issue body via `gh issue view <num> --json title,body,labels,state,comments`
- If a plan file guided the work (e.g. in `~/.claude/plans/`): its path

Review for:

- **Issue-spec adherence.** Implementation must match the linked gh issue.
- **Plan adherence.** Divergences from a written plan that weren't re-negotiated are findings.
- **Don't leave stuff on the table.** Every requirement in the issue and the plan must be implemented. No silent TODOs or stubs. A *better* solution than what the spec describes is fine — taking it is encouraged — but you cannot drop parts of the spec. (Genuinely substantial scope cuts can be deferred via a new gh issue, but this should be rare — don't suggest deferring small things.)
- **Performance bottlenecks.** Most code is solvers — look hard at hot loops, allocations, asymptotic complexity, copies, algorithmic choices. Flag even when "correct".
- Refactoring opportunities (dead code, duplication, weak abstractions).
- Logic bugs, edge cases, error handling gaps.
- Project standards (naming, style, conventions).
- Test coverage and quality.

**Reviewers do not edit files.** The orchestrator is the sole writer — this prevents the 3 parallel reviewers from racing on the shared working tree. Each agent returns a structured list of findings; for every finding it includes a `disposition`:

- `confident-fix`: the agent is confident in the fix. Must include a complete patch (file, exact `old_string` and `new_string`, or unified diff) the orchestrator can apply mechanically. Use for both small (typos, naming, missing types) and large (logic bugs, perf issues, refactors with a clear right answer) fixes.
- `uncertain`: architectural tradeoff, ambiguous requirement, missing context. Include the issue, why it matters, why uncertain, and the options as the agent sees them.

Each finding also has: file, line, issue, why it matters.

## Step 5: Consolidate and apply fixes

1. **Merge findings** from all 3 reviewers. Deduplicate (multi-flagged = higher confidence).
2. **Apply `confident-fix` patches** sequentially. If two patches touch the same lines and disagree, do not apply either — reclassify both as `uncertain` and surface the conflict to the user.
3. **Resolve uncertain findings the orchestrator itself can confidently fix** — apply those too rather than escalating.
4. **Resolve cross-reviewer contradictions** with judgment (e.g. reviewer A says "rename this", reviewer B says "name is fine" — pick one).

## Step 6: Run tests and commit

Run the test suite. If green, commit as `fix: address review findings`. If tests fail, identify the offending patch, revert just that patch, and reclassify it as `uncertain`. Re-run tests; commit when green.

## Step 7: Present the uncertain ones

Present the remaining uncertain findings to the user. Wait for the user's call before touching them.

## Step 8: Mark review complete

```bash
git rev-parse HEAD > "$(git rev-parse --absolute-git-dir)/.last-review"
```

This lets the pre-push hook and statusline know the review is up to date. After the next push, per `common.md` Git Workflow, close any resolved gh issues with `gh issue close <num> -c "..."` and delete the feature branch (if one was used).
