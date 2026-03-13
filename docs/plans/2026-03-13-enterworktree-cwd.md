# Plan: Document EnterWorktree CWD sharing and add workaround (Issue #33)

## Problem

When two lightbulb agents are launched in parallel from the same session, `EnterWorktree` changes the working directory for the entire session -- not just the agent that invoked it. This causes the second agent to find itself inside the first agent's worktree, unable to create its own.

### Root Cause Analysis

There are **two separate worktree mechanisms** in the lightbulb workflow, and their interaction creates the problem:

1. **`EnterWorktree`** (Claude Code platform tool) -- creates worktrees in `.claude/worktrees/` and "switches the session's working directory to the new worktree." This is a session-level side effect. Its description also states it requires "must not already be in a worktree."

2. **`superpowers:using-git-worktrees`** (skill) -- creates worktrees in `.worktrees/` (or `worktrees/`) and uses `cd "$path"` to change into them. This is a shell-level side effect that does not persist across Bash tool calls.

The lightbulb skill's Step 2 invokes `superpowers:using-git-worktrees`, which uses `cd` and `git worktree add`. However, when the lightbulb is launched via the Agent tool with `isolation: "worktree"`, the platform itself calls `EnterWorktree` to set up the agent's execution context *before* the agent starts. This `EnterWorktree` call modifies shared session state.

### Evidence from the repository

The worktree list shows the nesting pattern:

```
/home/maurezen/git_tree/around                                                  (main repo)
/home/maurezen/git_tree/around/.claude/worktrees/issue-30-simplify-review-diff  (EnterWorktree)
/home/maurezen/git_tree/around/.claude/worktrees/issue-30-simplify-review-diff/.claude/worktrees/agent-a8fdc750  (nested EnterWorktree)
/home/maurezen/git_tree/around/.worktrees/issue-33-enterworktree-cwd            (using-git-worktrees)
```

The `.claude/worktrees/` entries are created by `EnterWorktree`. The `.worktrees/` entries are created by `superpowers:using-git-worktrees`. The nested worktree (`agent-a8fdc750` inside `issue-30`) confirms that `EnterWorktree` was called from within an existing worktree -- contradicting its own "must not already be in a worktree" requirement.

### Why parallel lightbulb agents fail

1. **Agent #30** launches, `EnterWorktree` changes the session CWD to `.claude/worktrees/issue-30-...`
2. **Agent #31** launches (same session), finds itself already in `.claude/worktrees/issue-30-...`
3. Agent #31 tries to call `EnterWorktree` but fails because it's "already in a worktree"
4. Agent #31 falls back to the `superpowers:using-git-worktrees` skill, which tries to create `.worktrees/` relative to the current directory -- but the current directory is agent #30's worktree
5. The orchestrator's `pwd` also shows agent #30's worktree because `EnterWorktree` changed the session-level CWD

### Key insight

`EnterWorktree` is a **Claude Code platform behavior**, not something the lightbulb skill controls. The `superpowers:using-git-worktrees` skill does not call `EnterWorktree` -- it uses `git worktree add` + `cd`. But when agents are dispatched with `isolation: "worktree"` or when the skill is invoked in certain contexts, the platform may use `EnterWorktree` under the hood.

## Solution

Since `EnterWorktree` is a platform tool whose session-level CWD side effect cannot be changed by this project, the solution has two parts:

1. **Document the limitation** in the lightbulb SKILL.md so that users and the LLM understand why parallel agents from the same session fail.
2. **Add defensive guidance** to the lightbulb skill so that:
   - The orchestrator avoids dispatching parallel lightbulb agents from the same session
   - If parallel agents are needed, the guidance recommends using separate Claude Code sessions
   - The existing anti-piggybacking check (branch name verification in Step 2) catches cases where an agent ends up in the wrong worktree

### What NOT to change

- The `superpowers:using-git-worktrees` skill is an external dependency and cannot be modified.
- The `EnterWorktree` tool is a Claude Code platform tool and cannot be modified.
- The existing branch name verification in Step 2 already catches the piggybacking case -- no changes needed there.

## Tasks

### Task 1: Add "Known Limitation" section to SKILL.md

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

Add a new section after `## Error Handling` and before `## Red Flags` that documents the parallel agent limitation:

```markdown
## Known Limitations

### Parallel lightbulb agents share session CWD

The `EnterWorktree` tool (a Claude Code platform tool) changes the working directory for the **entire session**, not just the agent that invoked it. When two lightbulb agents are launched in parallel from the same session:

1. The first agent's worktree setup changes the session CWD
2. The second agent starts inside the first agent's worktree
3. The second agent cannot create its own worktree (already in a worktree)

**Workaround:** Launch parallel lightbulb agents from separate Claude Code sessions. Each session maintains its own CWD, so `EnterWorktree` in one session does not affect the other.

**Detection:** The branch name verification in Step 2 catches this case -- if an agent finds itself in a worktree whose branch doesn't match its issue number, it stops and reports the error rather than piggybacking on the wrong worktree.
```

### Task 2: Add "Never" red flag for parallel lightbulb agents

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

In the `**Never:**` list in the Red Flags section, add a new bullet after the existing item about chaining Bash commands:

```markdown
- Dispatch multiple lightbulb agents in parallel from the same session -- `EnterWorktree` shares CWD across the session, so the second agent will land in the first agent's worktree (see **Known Limitations**)
```

### Task 3: Update the orchestrator dispatch guidance

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

The existing "Red Flags > Never" list already contains "Dispatch subagents in parallel -- phases are sequential." This covers the *within-a-single-lightbulb* case. But a user might invoke `/lightbulb 30` and `/lightbulb 31` from the same session, expecting them to run in parallel.

Add a note to the top of the skill (after the `**Announce at start:**` block and before `## Input`) to make this explicit:

```markdown
**Parallel execution:** This skill does not support running multiple lightbulb instances in parallel from the same Claude Code session. Each lightbulb invocation modifies the session's working directory via worktree setup. To develop multiple issues in parallel, use separate Claude Code sessions (one per issue).
```

### Task 4: Verify the branch name check covers the failure mode

**Files:**
- Read (no modification): `skills/lightbulb/SKILL.md`

Verify that Step 2's existing branch name verification would catch the case described in the issue:

1. Agent #31 starts in agent #30's worktree (`.claude/worktrees/issue-30-...`)
2. The branch in that worktree is `feature/issue-30-...`
3. Agent #31's target issue is #31
4. The check: `echo "$CURRENT_BRANCH" | grep -q "issue-31"` -- fails because the branch contains `issue-30`, not `issue-31`
5. Agent #31 stops and reports error

This should already work. No changes needed -- just verify and document.

## Out of Scope

- Modifying the `EnterWorktree` tool (platform tool, not ours)
- Modifying `superpowers:using-git-worktrees` (external dependency)
- Implementing a workaround that avoids `EnterWorktree` entirely (would require forking the superpowers skill)
- Adding `isolation: "worktree"` guidance to the Agent tool dispatch (this is a Claude Code platform parameter, not something the skill controls)

## Verification

After all tasks:

1. **Read the complete SKILL.md** and verify:
   - The "Known Limitations" section exists between "Error Handling" and "Red Flags"
   - The "Parallel execution" note appears near the top of the skill
   - The new "Never" red flag about parallel lightbulb agents is present
   - No other sections were accidentally modified

2. **Trace the failure scenario through the updated logic:**
   - User runs `/lightbulb 30` and `/lightbulb 31` from the same session
   - The "Parallel execution" note at the top warns against this
   - If the user proceeds anyway:
     - Agent #30 creates worktree, session CWD changes
     - Agent #31 starts in agent #30's worktree
     - Step 2 branch verification catches the mismatch (`issue-30` != `issue-31`)
     - Agent #31 stops and reports the error
     - The "Known Limitations" section explains why this happened
   - Result: no piggybacking, clear error message, documented workaround

3. **Verify the "Never" red flag list** is consistent -- the new parallel-agents entry does not conflict with existing entries.
