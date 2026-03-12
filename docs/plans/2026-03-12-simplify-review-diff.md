# Plan: Simplify review loop diff command (Issue #30)

## Problem

The lightbulb skill's Step 6 (Review Loop) uses a compound shell command to get the diff against the base branch:

```bash
BASE=$(git -C "$WORKTREE_PATH" symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
git -C "$WORKTREE_PATH" diff $BASE...HEAD
```

This triggers Claude Code safety prompts due to variable expansion, pipe chains, and `&&` chaining.

## Solution

Replace the compound diff command with `gh pr diff <pr-number>`.

By Step 6, the draft PR already exists (created in Step 5), so `gh pr diff` is semantically correct -- we're reviewing the PR, so get the PR's diff. It's a single command with no piping, no expansion, and no base branch detection needed.

## Tasks

### Task 1: Replace the diff command in Step 6

**File:** `skills/lightbulb/SKILL.md`

**Location:** Step 6, item 1 (lines 251-255)

**Current text:**
```
1. Get the full diff against the base branch (detect it dynamically — do not hardcode `main`):

\```
BASE=$(git -C "$WORKTREE_PATH" symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
git -C "$WORKTREE_PATH" diff $BASE...HEAD
\```
```

**Replace with:**
```
1. Get the full diff for the PR:

\```
gh pr diff <pr-number>
\```
```

**Rationale:** The PR already exists by this point (created in Step 5). `gh pr diff` returns the same unified diff without any shell expansion, piping, or base branch detection. The reviewer subagent receives the same format either way.

### Task 2: Verify no other references depend on the BASE variable

Search the file for any other uses of the `BASE` variable or `symbolic-ref` pattern. The plan only applies if these appear solely in the Step 6 diff command block.

**Expected result:** No other references exist (confirmed by search -- only lines 254-255 match).

## Out of Scope

- Changes to subagent prompts (the reviewer just receives a diff string regardless of how it was obtained)
- Changes to any other steps in the flow
- Adding truncation (`| head -3000`) -- the issue notes this could be added separately if needed
