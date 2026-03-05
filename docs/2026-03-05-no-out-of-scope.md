# Do Not Do Out-of-Scope Things -- Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent the lightbulb orchestrator and its subagents from performing actions outside the scope of the target issue. The orchestrator should only execute actions defined in the skill flow for the issue it was invoked with. It must never spontaneously act on observations about other issues, PRs, or unrelated repository state.

**Architecture:** All changes are to a single file: `skills/lightbulb/SKILL.md`. The changes add explicit scope constraints at three levels:
1. A top-level scope principle near the beginning of the skill (after the Input section), making scope boundaries a first-class concept
2. Scope reminders in subagent prompt templates, so subagents inherit the constraint
3. New "Never" red flags for out-of-scope actions

**Tech Stack:** Claude Code skill (Markdown), no code dependencies.

---

## Background

During a `/lightbulb 12` session, the orchestrator -- after fetching issue #12 in Step 1 -- spontaneously attempted to close issue #14 as a duplicate of #10:

```
Also, let me close issue #14 as a duplicate of #10 since it was already fixed.

Bash(gh issue close 14 --comment "Duplicate of #10, which was already fixed in PR #11.")
  Tool use rejected with user message: it is out of scope of 12
```

The orchestrator noticed a relationship between issues #14 and #10 and decided to "help" by closing the duplicate. This is a violation of scope: the orchestrator was tasked with developing issue #12 and should not touch any other issue unless the issue body or flow explicitly requires it.

**Why this happened:** The SKILL.md has no explicit scope constraint. The flow implicitly assumes scope by describing specific steps, but there is nothing preventing the orchestrator from improvising additional actions between or alongside those steps. LLMs are prone to "helpful" tangential actions when they notice opportunities.

**Why the current Red Flags didn't prevent it:** The existing Red Flags list includes constraints like "never write code yourself" and "never skip the review loop," but nothing about staying within the scope of the target issue. The orchestrator was not violating any explicit rule -- it was doing something the rules were silent about.

**Defense-in-depth consideration:** The permission system (`gh issue close` is not in the allowed permissions list) did catch this at the final gate, but relying on permissions as a scope guard is fragile and confusing. The user had to manually reject the action. The fix should prevent the orchestrator from even considering out-of-scope actions.

---

## Task 1: Add a Scope section to SKILL.md

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

### Step 1: Insert a Scope section after the Input section

In `skills/lightbulb/SKILL.md`, find the end of the Input section. The Input section ends with:

```
Parse these from the user's message. If the message contains a `#N` reference or bare number referring to a GitHub issue, use issue mode. If it contains a topic/idea description without an issue number, use topic mode. If ambiguous, ask.
```

After that paragraph and before the `## Flow` section, insert a new section:

```markdown

## Scope

**All actions must serve the target issue.** The orchestrator and its subagents must only perform actions that are part of the defined flow for the issue they were invoked with. Specifically:

- **Do not** act on observations about other issues, PRs, labels, or repository state that are not directly required by the target issue's flow.
- **Do not** close, comment on, triage, or modify other issues -- even if they appear to be duplicates, related, or stale.
- **Do not** modify files, branches, or PRs that are not part of the current worktree and development flow.
- **Do** stay strictly within the steps defined in the Flow section below. If you notice something outside the target issue that seems worth doing, ignore it -- the user can handle it separately.

If the target issue's body explicitly references another issue as a dependency or prerequisite (e.g., "this depends on #5 being merged first"), you may read that issue for context but must not modify it.
```

### Step 2: Verify the section is in the right place

Run: `grep -n "## Scope\|## Input\|## Flow" skills/lightbulb/SKILL.md`

Expected: three matches, in this order: `## Input`, `## Scope`, `## Flow`.

### Step 3: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add Scope section to prevent out-of-scope actions"
```

---

## Task 2: Add scope reminders to subagent prompt templates

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

The orchestrator dispatches 6 types of subagents. Each subagent prompt should include a scope reminder so subagents also stay focused. The reminder should be brief -- subagents are already task-focused by nature, but an explicit note prevents drift.

### Step 1: Add scope line to the brainstorming subagent prompt (Step 0b)

In `skills/lightbulb/SKILL.md`, find the brainstorming subagent prompt block (Step 0b). At the end of the prompt blockquote, after the line:

```
> When you need user input, return a message starting with `USER_INPUT_NEEDED:` followed by the question.
```

Add:

```
>
> **Scope:** Stay focused on the topic provided. Do not act on observations about other issues, PRs, or unrelated repository state.
```

### Step 2: Add scope line to the planning subagent prompt (Step 3)

In the planning subagent prompt block (Step 3), at the end of the prompt blockquote, after the line:

```
> When the plan is complete, return a message starting with `PLAN_COMPLETE:` followed by the plan file path.
```

Add:

```
>
> **Scope:** Stay focused on issue #{N}. Do not act on observations about other issues, PRs, or unrelated repository state.
```

### Step 3: Add scope line to the implementation subagent prompt (Step 4)

In the implementation subagent prompt block (Step 4), at the end of the prompt blockquote, after the line:

```
> When implementation is complete, return a message starting with `IMPLEMENTATION_COMPLETE:` followed by a summary of what was implemented.
```

Add:

```
>
> **Scope:** Implement only what the plan specifies. Do not act on observations about other issues, PRs, or unrelated repository state.
```

### Step 4: Add scope line to the reviewer subagent prompt (Step 6)

In the reviewer subagent prompt block (Step 6), at the end of the prompt blockquote, after the closing ` ``` ` of the review format:

Add:

```
>
> **Scope:** Review only the diff provided. Do not comment on or act on other issues, PRs, or unrelated repository state.
```

### Step 5: Add scope line to the fixer subagent prompt (Step 6, NEEDS_FIXES)

In the fixer subagent prompt block (Step 6), at the end of the prompt blockquote, after:

```
> When done, return `FIXES_COMPLETE:` followed by a summary.
```

Add:

```
>
> **Scope:** Fix only the listed issues. Do not act on observations about other issues, PRs, or unrelated repository state.
```

### Step 6: Add scope line to the CI fixer subagent prompt (Step 7)

In the CI fixer subagent prompt block (Step 7), at the end of the prompt blockquote, after:

```
> Fix the issue, run tests locally to verify, and commit.
```

Add:

```
>
> **Scope:** Fix only the CI failure. Do not act on observations about other issues, PRs, or unrelated repository state.
```

### Step 7: Verify all prompts were updated

Run: `grep -c "Scope.*Stay focused\|Scope.*Fix only\|Scope.*Review only\|Scope.*Implement only" skills/lightbulb/SKILL.md`

Expected: `6` (one per subagent prompt).

### Step 8: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add scope reminders to all subagent prompts"
```

---

## Task 3: Add "Never" red flags for out-of-scope actions

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

### Step 1: Add new red flags to the Never list

In `skills/lightbulb/SKILL.md`, find the `**Never:**` list in the Red Flags section. Add these bullets after the existing last item ("Accept an APPROVED review that has Critical or Important issues -- always override to NEEDS_FIXES"):

```
- Act on observations about other issues, PRs, or repository state that are outside the target issue's flow -- even if they seem helpful (e.g., closing duplicates, triaging, commenting on other PRs)
- Run commands not defined in the skill flow (e.g., `gh issue close`, `gh issue edit`, `gh pr close` are never part of the lightbulb flow)
```

### Step 2: Verify the red flags are present

Run: `grep -n "outside the target\|not defined in the skill flow" skills/lightbulb/SKILL.md`

Expected: two matches, both in the Red Flags section.

### Step 3: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add red flags for out-of-scope actions"
```

---

## Verification

After all tasks:

1. **Read the complete SKILL.md** end-to-end and verify:
   - The Scope section exists between Input and Flow
   - The Scope section has four "Do not" bullets and one "Do" bullet
   - All 6 subagent prompt templates include a `**Scope:**` line
   - The Red Flags "Never" list includes the two new out-of-scope bullets
   - No other sections were accidentally modified

2. **Trace the issue #15 scenario through the updated logic:**
   - Orchestrator invoked with `/lightbulb 12`
   - Step 1: Fetches issue #12
   - Orchestrator notices issue #14 appears to be a duplicate of #10
   - Scope section: "Do not close, comment on, triage, or modify other issues -- even if they appear to be duplicates, related, or stale"
   - Red Flag: "Act on observations about other issues... even if they seem helpful (e.g., closing duplicates, triaging)"
   - Red Flag: "Run commands not defined in the skill flow (e.g., `gh issue close`...)"
   - Result: three independent rules prevent the out-of-scope action

3. **Verify no over-constraint:** The Scope section allows reading referenced issues for context (e.g., if the target issue says "depends on #5"). This preserves the ability to understand cross-issue dependencies without acting on them.
