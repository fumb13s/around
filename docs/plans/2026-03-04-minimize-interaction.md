# Minimize Unnecessary Human Interaction -- Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce unnecessary human interaction in the lightbulb skill by fixing subagent permission modes and commit command patterns, and auditing for other interaction-triggering patterns.

**Architecture:** All changes are to a single file: `skills/lightbulb/SKILL.md`. The changes fall into three categories:
1. Add `permissionMode: "acceptEdits"` to all subagent dispatch instructions so file edits don't trigger permission prompts
2. Replace `$(cat <<'EOF' ... EOF)` HEREDOC patterns with simpler `-m` flag patterns for `git commit` commands, and use HEREDOC consistently for `gh` commands where multiline bodies are needed
3. Fix the `gh pr comment` command to safely handle multiline review content containing backticks and special characters

**Tech Stack:** Claude Code skill (Markdown), no code dependencies.

**Analysis of interaction sources:**

| Source | Type | Fix |
|--------|------|-----|
| Subagent file edit permissions | Unnecessary | Add `permissionMode: "acceptEdits"` to all subagent dispatches |
| `git commit` with HEREDOC/cat | Unnecessary | Claude Code's system prompt uses cat/HEREDOC for commit messages, which triggers an unconditional confirmation request; use simple `-m` flag instead |
| `gh issue create` with HEREDOC | Acceptable | HEREDOC is needed here for multiline markdown with backticks/quotes in the body; this is a `gh` command, not `git commit` |
| `gh pr create` with HEREDOC | Acceptable | Same as above -- multiline PR body needs HEREDOC for shell safety |
| `gh pr comment` with bare quotes | Bug (not interaction) | Review content contains backticks and special chars that will break shell quoting; should use HEREDOC for safety |
| `USER_INPUT_NEEDED` relay | Necessary | Deliberate design -- subagents ask clarifying questions |
| Step 8 user prompt (mark ready/merge) | Necessary | Deliberate design -- user consent before PR state changes |
| Step 6.7 cosmetic fix prompt | Necessary | Deliberate design -- user choice on optional work |
| Error handling user prompts | Necessary | Deliberate design -- user decides retry/skip/abort |

**Key insight on `permissionMode`:** The Claude Code Agent tool (used to dispatch subagents) supports a `permissionMode` parameter in YAML frontmatter with values: `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`. The `acceptEdits` mode auto-approves file edits while still prompting for shell commands. Since all our subagents need to edit files but their shell commands are controlled by the skill's instructions, `acceptEdits` is the right choice.

The lightbulb skill dispatches subagents inline via the Agent tool with prose instructions like `(Agent tool, subagent_type: "general-purpose", model: "opus")`. We need to add `permissionMode: "acceptEdits"` to each dispatch instruction.

---

## Task 1: Add `permissionMode: "acceptEdits"` to all subagent dispatch instructions

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

There are 6 subagent dispatch sites in the skill. Each needs `permissionMode: "acceptEdits"` added to its dispatch parameters.

### Step 1: Update the brainstorming subagent dispatch (Step 0b)

In `skills/lightbulb/SKILL.md`, find line 54:

```
Dispatch a brainstorming subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`) with this prompt structure:
```

Replace with:

```
Dispatch a brainstorming subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with this prompt structure:
```

### Step 2: Update the planning subagent dispatch (Step 3)

Find line 112:

```
Dispatch a planning subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`) with this prompt structure:
```

Replace with:

```
Dispatch a planning subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with this prompt structure:
```

### Step 3: Update the implementation subagent dispatch (Step 4)

Find line 143:

```
Dispatch an implementation subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`) with this prompt structure:
```

Replace with:

```
Dispatch an implementation subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with this prompt structure:
```

### Step 4: Update the reviewer subagent dispatch (Step 6)

Find line 202:

```
3. Dispatch a reviewer subagent (Agent tool, `subagent_type: "superpowers:code-reviewer"`, `model: "opus"`) with:
```

Replace with:

```
3. Dispatch a reviewer subagent (Agent tool, `subagent_type: "superpowers:code-reviewer"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with:
```

### Step 5: Update the fixer subagent dispatch (Step 6, NEEDS_FIXES branch)

Find line 263:

```
   Dispatch a fixer subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`) with:
```

Replace with:

```
   Dispatch a fixer subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with:
```

### Step 6: Update the CI fixer subagent dispatch (Step 7)

Find line 296:

```
If checks fail, dispatch a fixer subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`) with the failure output:
```

Replace with:

```
If checks fail, dispatch a fixer subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with the failure output:
```

### Step 7: Verify all dispatches were updated

Run: `grep -c 'permissionMode: "acceptEdits"' skills/lightbulb/SKILL.md`

Expected: `6`

Also verify no dispatch sites were missed:

Run: `grep -n 'Agent tool' skills/lightbulb/SKILL.md`

Every line matching `Agent tool` that dispatches a subagent should include `permissionMode: "acceptEdits"`. The only `Agent tool` references that should NOT have it are references in relay pattern descriptions (e.g., "resume the subagent (Agent tool with `resume` parameter)").

### Step 8: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add acceptEdits permission mode to all subagent dispatches

Subagents were triggering edit permission prompts on every file
modification, requiring unnecessary human confirmation. Adding
permissionMode: acceptEdits auto-approves file edits while still
prompting for shell commands."
```

---

## Task 2: Simplify git commit commands to avoid confirmation prompts

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

The skill currently has one `git commit` command (in Step 3, after the plan phase). Claude Code's system prompt instructs it to use `cat <<'EOF'` HEREDOC patterns for commit messages for readability, but this triggers an unconditional confirmation request. The simple `-m` flag does not.

### Step 1: Verify the commit command pattern

Find lines 135-137 in `skills/lightbulb/SKILL.md`:

```
git add docs/*.md
git commit -m "docs: add implementation plan for issue #N"
```

This commit command already uses the simple `-m` flag pattern. No change needed here.

### Step 2: Add a guidance note to prevent HEREDOC drift

Since the skill instructs Claude to commit at various points (plan phase, fix phases, CI fixes), and Claude Code's default system prompt encourages HEREDOC patterns for commits, add an explicit instruction to the Red Flags section to prevent drift.

In `skills/lightbulb/SKILL.md`, find the "Always:" list in the Red Flags section. Add a new bullet:

```
- Use simple `git commit -m "message"` — never use HEREDOC/cat patterns for commit messages (they trigger unnecessary confirmation prompts)
```

Add this after the existing bullet "Commit after each phase (plan, implementation fixes, review fixes, CI fixes)".

### Step 3: Verify the red flag is present

Run: `grep -n "HEREDOC" skills/lightbulb/SKILL.md`

Expected: matches in the Red Flags section (the new bullet) and in the `gh issue create` / `gh pr create` sections (where HEREDOC is correctly used for multiline bodies).

### Step 4: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add red flag against HEREDOC commit messages

Claude Code's system prompt encourages HEREDOC/cat patterns for git
commit messages, but these trigger unnecessary confirmation prompts.
Adding an explicit instruction to use simple -m flag instead."
```

---

## Task 3: Fix `gh pr comment` to safely handle multiline review content

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

The current `gh pr comment` command uses bare double quotes around the review content. Since review content contains backticks, code blocks, and special characters, this will break shell quoting. It should use the same HEREDOC pattern as `gh issue create` and `gh pr create`.

### Step 1: Replace the gh pr comment command

Find lines 251-255:

```
```
gh pr comment <pr-number> --body "<review-content>

— Claude"
```
```

Replace with:

```
```
gh pr comment <pr-number> --body "$(cat <<'EOF'
<review-content>

— Claude
EOF
)"
```
```

### Step 2: Verify the edit

Read the relevant section and confirm the `gh pr comment` command now uses the HEREDOC pattern.

### Step 3: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): use HEREDOC for gh pr comment body

Review content contains backticks, code blocks, and special characters
that break bare double-quote shell quoting. Using the same HEREDOC
pattern as gh issue create and gh pr create."
```

---

## Verification

After all tasks:

1. **Read the complete SKILL.md** end-to-end and verify:
   - All 6 subagent dispatch instructions include `permissionMode: "acceptEdits"`
   - No `Agent tool` dispatch site was missed (relay/resume references excluded)
   - The Red Flags "Always" section includes the HEREDOC warning
   - The `gh pr comment` command uses the HEREDOC pattern
   - No other sections were accidentally modified
   - The `gh issue create` and `gh pr create` commands still correctly use HEREDOC (they need it for multiline markdown bodies)

2. **Trace through the interaction model:**
   - Subagent dispatched with `permissionMode: "acceptEdits"` -> file edits auto-approved, no permission prompt -> correct
   - `git commit -m "message"` -> no HEREDOC, no confirmation prompt -> correct
   - `gh pr comment` with HEREDOC -> shell-safe multiline body, gh handles quoting -> correct
   - `USER_INPUT_NEEDED` relay -> deliberate user interaction, unchanged -> correct
   - Step 8 completion prompt -> deliberate user interaction, unchanged -> correct
