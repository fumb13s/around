# Never Piggyback on Another Agent's Branch or Worktree -- Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent a lightbulb agent from committing to or working in a worktree/branch that belongs to a different issue. When an agent cannot access its own worktree, it should report the failure and stop rather than falling back to another agent's workspace.

**Architecture:** All changes are to a single file: `skills/lightbulb/SKILL.md`. The changes add:
1. A worktree ownership verification step after worktree setup (Step 2)
2. New "Never" red flags for piggybacking on another agent's workspace
3. An "Always" red flag reinforcing the verification requirement

**Tech Stack:** Claude Code skill (Markdown), no code dependencies.

---

## Background

When three lightbulb agents were dispatched in parallel for issues #18, #19, and #20, agent #18 failed to access its own worktree and instead piggybacked on agent #19's worktree and branch (`worktree-feature/issue-19-readme-what-to-expect`). This resulted in PR #21 containing commits for both issues #18 and #19, mixing unrelated work on a single branch.

**How the piggybacking happened:** The `using-git-worktrees` skill creates worktrees in a shared `.worktrees/` directory. When agent #18 failed to create or access its own worktree (likely due to a race condition or filesystem error with parallel agents), it did not stop. Instead, it found and used agent #19's already-existing worktree directory. Since the lightbulb SKILL.md had no rule against working in a worktree that belongs to a different issue, agent #18 proceeded to commit its changes (for issue #18) onto agent #19's branch.

**Why existing rules didn't prevent it:**
- The Scope section says "Do not modify files, branches, or PRs that are not part of the current worktree and development flow" -- but agent #18 *adopted* agent #19's worktree as its own, so from its perspective it was working in "its" worktree.
- The Red Flags "Never" list covers out-of-scope actions on other issues, but the agent was still working on its own issue (#18) -- just in the wrong workspace.
- There is no post-setup verification step that checks whether the worktree and branch actually correspond to the agent's issue number.

**The fix needs to close this gap** by making worktree ownership an explicit invariant: the agent must verify that its worktree and branch name match its issue number, and if they don't, it must stop.

---

## Task 1: Add worktree ownership verification to Step 2

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

### Step 1: Add a verification sub-step to Step 2

In `skills/lightbulb/SKILL.md`, find the Step 2 section. It currently reads:

```
## Step 2: Set Up Worktree

**REQUIRED SUB-SKILL:** Use `superpowers:using-git-worktrees` to create an isolated workspace.

The worktree branch name should be derived from the issue: `feature/issue-<number>-<slug>` where `<slug>` is a short kebab-case summary of the issue title.
```

Replace it with:

```
## Step 2: Set Up Worktree

**REQUIRED SUB-SKILL:** Use `superpowers:using-git-worktrees` to create an isolated workspace.

The worktree branch name should be derived from the issue: `feature/issue-<number>-<slug>` where `<slug>` is a short kebab-case summary of the issue title.

**After worktree setup, verify ownership:**

```bash
# Verify the current branch contains this issue's number
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "$CURRENT_BRANCH" | grep -q "issue-<number>" || echo "BRANCH_MISMATCH"
```

If the branch name does not contain `issue-<number>` (where `<number>` is your target issue number), **stop immediately** and report the error to the user. Do not proceed to Step 3. This prevents piggybacking on another agent's worktree when parallel agents are running.
```

### Step 2: Verify the section reads correctly

Run: `grep -A 10 "## Step 2" skills/lightbulb/SKILL.md`

Expected: The Step 2 section should show the worktree setup instructions followed by the ownership verification block.

### Step 3: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add worktree ownership verification to Step 2"
```

---

## Task 2: Add "Never" red flags for piggybacking

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

### Step 1: Add new red flags to the Never list

In `skills/lightbulb/SKILL.md`, find the `**Never:**` list in the Red Flags section. Add this bullet after the existing last item in the Never list ("Run commands not defined in the skill flow (e.g., `gh issue close`, `gh issue edit`, `gh pr close` are never part of the lightbulb flow)"):

```
- Work in a worktree or commit to a branch that belongs to a different issue -- if your worktree is inaccessible or the branch name doesn't match your issue number, report the error and stop
```

### Step 2: Add a new "Always" red flag for verification

In `skills/lightbulb/SKILL.md`, find the `**Always:**` list in the Red Flags section. Add this bullet after the existing last item in the Always list ("Ensure all orchestrator Bash commands have matching entries in the user's `permissions.allow` -- see README for the setup script and manual list"):

```
- Verify after worktree setup that the current branch name contains your issue number -- never proceed if it doesn't match
```

### Step 3: Verify the red flags are present

Run: `grep -n "belongs to a different issue\|Verify after worktree setup" skills/lightbulb/SKILL.md`

Expected: two matches, both in the Red Flags section.

### Step 4: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add red flags against piggybacking on another agent's worktree"
```

---

## Verification

After all tasks:

1. **Read the complete SKILL.md** end-to-end and verify:
   - Step 2 includes the ownership verification sub-step with the branch name check
   - The Red Flags "Never" list includes the piggybacking prohibition
   - The Red Flags "Always" list includes the post-setup verification requirement
   - No other sections were accidentally modified

2. **Trace the issue #18 failure scenario through the updated logic:**
   - Agent #18 invoked with `/lightbulb 18`
   - Step 1: Fetches issue #18
   - Step 2: Attempts to create worktree with branch `feature/issue-18-...`
   - Worktree creation fails (race condition with parallel agents)
   - Agent finds agent #19's worktree at `.worktrees/feature/issue-19-...`
   - Ownership verification: checks current branch `feature/issue-19-...` for `issue-18` -- MISMATCH
   - Agent stops and reports error to user
   - Red Flag "Never work in a worktree or commit to a branch that belongs to a different issue" reinforces the stop
   - Result: piggybacking prevented

3. **Verify no over-constraint:** The verification only checks that the branch name contains the target issue number. It does not restrict branch naming beyond that, so custom branch naming patterns that include the issue number will still work.
