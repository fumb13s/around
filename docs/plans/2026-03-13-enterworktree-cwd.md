# Plan: Fix EnterWorktree CWD sharing (Issue #33)

## Problem

`EnterWorktree` changes the session CWD for the **entire session**, not just the agent that invoked it. This was confirmed experimentally:

- Two parallel agents launched from main repo root
- Agent A called `EnterWorktree` (no exit)
- Parent session CWD changed to agent A's worktree
- Agent B was unaffected (launched before the side effect)

This breaks parallel lightbulb execution — the second agent lands in the first's worktree.

## Root Cause

`EnterWorktree` is a session-level operation. `ExitWorktree` restores the CWD, but lightbulb agents don't call it (they leave worktrees around for PRs). The `isolation: "worktree"` parameter also doesn't protect — agents inside isolated worktrees that call `EnterWorktree` still corrupt the parent session CWD.

## Solution

Replace `superpowers:using-git-worktrees` in Step 2 with direct `git worktree add` + `git -C`. This avoids all CWD-changing mechanisms:

```bash
ls -d .worktrees 2>/dev/null || mkdir .worktrees
git check-ignore -q .worktrees || echo ".worktrees" >> .gitignore
git worktree add .worktrees/issue-<N>-<slug> -b feature/issue-<N>-<slug>
WORKTREE_PATH="<repo-root>/.worktrees/issue-<N>-<slug>"
```

Verified: two parallel agents using this approach both created worktrees successfully without CWD corruption.

## Changes

1. **Step 2** — replaced `superpowers:using-git-worktrees` with direct `git worktree add` instructions
2. **Red Flags** — added "Never use EnterWorktree or superpowers:using-git-worktrees"
3. **Integration** — moved `using-git-worktrees` from "called" to "NOT called" with explanation
4. **Flow diagram** — removed "REQUIRED SUB-SKILL" reference
