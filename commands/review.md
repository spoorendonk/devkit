Run a multi-agent code review on all changes vs main. Follow these steps exactly.

## Options (from $ARGUMENTS)

- `--quick`: Do the review directly (no agents). Faster, less thorough.
- `--stamp`: Skip the review entirely — just write the current HEAD to `.devkit/.last-review`. Use when you've already reviewed manually.

If `--stamp` is passed, skip directly to the final step (mark review complete).

## Step 1: Sync with remote and determine diff base

Run `git fetch origin main` (or `master` if main doesn't exist) to get the latest remote state.

Determine the current branch:
```bash
BRANCH=$(git symbolic-ref --short HEAD)
```

**If on main/master:**
- The diff base is `origin/main` (review unpushed commits).

**If on a feature branch:**
1. Check if local main is behind origin/main:
   ```bash
   git rev-list --count main..origin/main
   ```
2. If behind, tell the user how many commits main is behind and suggest updating main + rebasing. Ask before doing anything.
3. If the user agrees:
   - `git checkout main && git pull --ff-only origin main`
   - `git checkout <feature-branch> && git rebase main`
   - If rebase has conflicts, stop and let the user resolve them
4. If the user declines, continue with the current state.
5. The diff base is `main`.

## Step 2: Gather the diff

Run `git diff <diff-base>...HEAD` to get all committed changes (where `<diff-base>` is `origin/main` on main, or `main` on a feature branch). Also run `git diff` and `git diff --cached` for any uncommitted changes. Combine these into the full changeset to review.

If there are no changes vs the diff base, report that and stop.

## Step 3: Read the standards

Read the project's standards files (the ones imported via `@.devkit/standards/` in CLAUDE.md) so reviewers know what conventions to check against.

## Step 4: Review

**If `--quick`:** Do the review yourself directly — no agents. Read the full source files (not just the diff) for context. Produce findings and skip to step 6.

**Otherwise:** Launch **3** agents simultaneously using the Agent tool. Each agent does a **full, independent review** of everything — correctness, style, tests, cleanliness. They are not split by domain. Think of them as different team members each reviewing the same code.

Each agent receives:
- The full diff from Step 2
- The relevant source files (not just the diff — read the full files for context)
- The standards from Step 3
- If the work is linked to a gh issue: the issue body, fetched via `gh issue view <num> --json title,body,labels,state,comments`
- If a plan file guided the work (e.g. in `~/.claude/plans/`): its path, passed explicitly to each agent so the subagent session has it in context

Review for:
- **Issue-spec adherence.** If the branch or PR is linked to a gh issue, verify the implementation actually matches what the issue asked for.
- **Plan adherence.** If a plan was written for this work, verify the implementation follows it. Divergences from the plan that weren't re-negotiated with the user are major findings.
- **Scope completeness.** Everything in the issue spec *and* the plan must be implemented, or explicitly deferred via a newly opened gh issue. No silent TODOs, no "will fix later" stubs, no partial implementations.
- **No shortcut implementations.** Reject "simple placeholder now, do it properly later" work. The first implementation must be the best one — call this out as a major finding if spotted.
- **Refactoring opportunities.** Dead code, duplication, complexity, weak abstractions.
- **Performance bottlenecks.** Critical: most of our code is solvers. Look hard at hot loops, allocation in inner loops, asymptotic complexity, unnecessary copies, and algorithmic choices. Flag perf concerns as major even when code is "correct".
- Logic bugs, edge cases, error handling gaps.
- Adherence to project standards (naming, style, conventions).
- Test coverage gaps and test quality.
- Anything else that looks wrong or could be improved.

Each agent returns a structured list of findings with: file, line, issue, severity (nit vs major), and suggested fix.

## Step 5: Consolidate findings

After all 3 agents complete, act as the orchestrator:
1. Merge all findings from the 3 reviewers
2. Deduplicate — issues flagged by multiple reviewers have higher confidence
3. Resolve contradictions between reviewers (if reviewer A says "rename this" and reviewer B says "the name is fine", use judgment)
4. Categorize each finding as:
  - **Nit**: small fix that can be applied automatically (typos, naming, simple refactors, missing type hints)
  - **Major**: requires human decision (logic changes, architectural concerns, ambiguous tradeoffs)

## Step 6: Auto-fix nits

Apply all nit fixes directly. After applying, run the test suite to make sure nothing broke. If tests pass, create a commit with message "fix: address review nits".

If tests fail after fixes, revert the nit fixes and reclassify them as major.

## Step 7: Present major issues

Present remaining major issues to the user in a clear list:
- File and line number
- What the issue is
- Why it matters
- Suggested approach (but don't implement without user approval)

Ask the user which issues to address and how.

## Step 8: Mark review complete

Write the current HEAD commit hash to `.devkit/.last-review`:

```bash
git rev-parse HEAD > .devkit/.last-review
```

This lets the pre-push hook and statusline know the review is up to date.
