# Reinforce git -C Convention -- Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the `git -C "$WORKTREE_PATH"` convention impossible for the LLM to ignore by promoting it to a top-level section, strengthening the Red Flags, and eliminating any remaining patterns that could serve as `cd && git` exemplars.

**Architecture:** All changes are to a single file: `skills/lightbulb/SKILL.md`. The changes:
1. Add a new `## Git Commands` top-level section between `## Flow` and `## Topic Mode: Step 0b` that establishes `git -C` as a fundamental principle
2. Remove the duplicated convention explanation from Step 2 (which becomes redundant once promoted)
3. Add an explicit "Never" red flag that calls out `cd` by name as a prohibited pattern
4. Audit all code blocks and inline code for any remaining `&&` chains or `cd`-based patterns

**Tech Stack:** Claude Code skill (Markdown), no code dependencies.

**Out of scope:**
- Removing `Bash(cd *)` from `scripts/setup-permissions.sh` and `README.md` -- that permission may still be needed by the `superpowers:using-git-worktrees` sub-skill or other contexts. A separate issue should address permission cleanup if desired.
- Changes to subagent prompt templates -- subagents run in the worktree context via the Agent tool and do not need `git -C`.

---

## Background

Issue #25 (PR #26) introduced the `git -C "$WORKTREE_PATH"` convention to replace `cd <path> && git <command>` chains that trigger Claude Code's bare repository security prompts. The convention was documented in three places:

1. **Step 2** (line 131): A paragraph explaining the convention, sandwiched between the `WORKTREE_PATH` variable assignment and the branch verification code block
2. **Code blocks** (Steps 3, 5, 6): All orchestrator git commands correctly use `git -C`
3. **Red Flags "Always" list** (line 398): A bullet mentioning the convention

Despite this, the LLM orchestrator was observed falling back to `cd /path && git add && git commit` in practice. The root cause: LLMs default to `cd && git` from training data, and the current instruction placement (a paragraph buried in Step 2, a bullet at the end of a long list) is insufficient to override this default.

**Why the current placement fails:**
- Step 2 is about worktree setup. The `git -C` convention applies to *all subsequent steps*, not just Step 2. Placing it there makes it feel like a Step-2-specific tip rather than a universal rule.
- The Red Flags section is at the very end of the file (line 372+). By the time the LLM reaches Step 3 or Step 5 where it needs to emit git commands, the Red Flag is far from the relevant context.
- There is no "Never" entry that explicitly prohibits `cd` -- only an "Always" entry that prescribes `git -C`. A prohibition is stronger than a prescription for overriding trained defaults.

**Strategy:** Promote the convention to a top-level section that appears *before* any step-specific instructions. This way, the LLM encounters the rule as a fundamental principle before it starts executing steps. Reinforce with an explicit "Never use cd" prohibition in Red Flags.

---

## Task 1: Add a `## Git Commands` top-level section

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

### Step 1: Insert the new section between `## Flow` and `## Topic Mode: Step 0b`

In `skills/lightbulb/SKILL.md`, find the end of the `## Flow` section. It ends with:

```
  8. Ask user: mark PR ready (default) or merge
```
```

After the closing triple-backtick of the Flow diagram (line 57), and before `## Topic Mode: Step 0b — BRAINSTORM Phase` (line 59), insert the following new section:

```markdown

## Git Commands

**All orchestrator git commands that target the worktree MUST use `git -C "$WORKTREE_PATH"`.**

The orchestrator stores the worktree path in `WORKTREE_PATH` after Step 2 creates it. Every git command from Step 3 onward must use the `-C` flag to target that path. This is the single most important convention in this skill for avoiding Claude Code security prompts.

**Correct:**
```bash
git -C "$WORKTREE_PATH" add docs/plans/*.md
git -C "$WORKTREE_PATH" commit -m "docs: add plan"
git -C "$WORKTREE_PATH" push -u origin feature/issue-42-foo
```

**Wrong -- NEVER do this:**
```bash
cd "$WORKTREE_PATH" && git add docs/plans/*.md
cd "$WORKTREE_PATH" && git commit -m "docs: add plan"
```

The `cd && git` pattern triggers Claude Code's bare repository security prompts. The `git -C` flag runs git against a different directory without changing the shell's CWD, which avoids the prompt entirely.

**Subagents are exempt:** Subagents dispatched via the Agent tool run in the worktree directory context automatically. They use plain `git add`, `git commit`, etc. Only the orchestrator needs `git -C`.
```

### Step 2: Verify the section ordering

Run: `grep -n "^## " skills/lightbulb/SKILL.md | head -10`

Expected ordering (first 10 `##` headings): Input, Scope, Flow, **Git Commands**, Topic Mode: Step 0b, Topic Mode: Step 0c, Step 1, Step 2, Step 3, Step 4.

### Step 3: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add top-level Git Commands section for git -C convention"
```

---

## Task 2: Slim down the Step 2 convention text

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

Now that the convention has a dedicated top-level section, Step 2 should reference it briefly rather than re-explaining it.

### Step 1: Replace the convention paragraph in Step 2

In `skills/lightbulb/SKILL.md`, find the Step 2 section. After the `WORKTREE_PATH` variable assignment block, there is currently this paragraph:

```
Use `git -C "$WORKTREE_PATH"` for **all** git commands that target the worktree. This avoids `cd <path> && git <command>` chains that trigger Claude Code's bare repository security prompts.
```

Replace it with:

```
Use `git -C "$WORKTREE_PATH"` for all subsequent git commands (see **Git Commands** section above).
```

This keeps a brief reminder in context while pointing to the authoritative section.

### Step 2: Verify

Run: `grep -n "Git Commands.*above\|see.*Git Commands" skills/lightbulb/SKILL.md`

Expected: One match in the Step 2 section.

### Step 3: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): replace Step 2 convention paragraph with cross-reference"
```

---

## Task 3: Add explicit "Never" red flag for `cd`

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

### Step 1: Add a "Never" entry to the Red Flags section

In `skills/lightbulb/SKILL.md`, find the `**Never:**` list in the Red Flags section. Add this bullet after the existing item about worktrees belonging to a different issue (the last "Never" bullet):

```
- Use `cd` to change into a worktree directory -- not in a `cd && git` chain, not as a standalone `cd` before git commands, not ever. Use `git -C "$WORKTREE_PATH"` instead (see **Git Commands** section)
```

### Step 2: Strengthen the existing "Always" entry

In the `**Always:**` list, find the existing bullet:

```
- Use `git -C "$WORKTREE_PATH"` for all orchestrator git commands targeting the worktree -- never use `cd <path> && git <command>` chains, as they trigger Claude Code's bare repository security prompts
```

Replace it with:

```
- Use `git -C "$WORKTREE_PATH"` for all orchestrator git commands targeting the worktree (see **Git Commands** section)
```

This shortens it (less text = easier to parse) and points to the authoritative section rather than re-explaining the rationale inline.

### Step 3: Verify

Run: `grep -n "cd.*worktree directory\|Git Commands.*section" skills/lightbulb/SKILL.md`

Expected: At least three matches -- one in the new "Never" entry, one in the updated "Always" entry, and one in Step 2.

### Step 4: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add explicit Never-cd red flag and streamline Always entry"
```

---

## Task 4: Audit for remaining `&&` chains and `cd` patterns

**Files:**
- Modify: `skills/lightbulb/SKILL.md` (only if issues found)

### Step 1: Search for all `&&` occurrences

Run: `grep -n '&&' skills/lightbulb/SKILL.md`

For each match, determine if it is:
- (a) Inside a code block that the orchestrator will execute -- these must be split into separate `git -C` calls
- (b) Inside a subagent prompt blockquote (lines starting with `>`) -- exempt, subagents run in worktree context
- (c) In descriptive/negative-example text (e.g., "never do X && Y") -- acceptable as documentation

If any (a) matches are found, split them into separate commands using `git -C`.

### Step 2: Search for all `cd ` occurrences in code blocks

Run: `grep -n 'cd ' skills/lightbulb/SKILL.md`

Same classification as above. Any (a) matches must be rewritten to use `git -C`.

### Step 3: If no changes were needed

If the audit finds no remaining problematic patterns (which is expected since issue #25 already cleaned them), report "Audit complete, no remaining issues" and skip the commit.

### Step 4: If changes were needed, commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): break remaining && chains into separate git -C calls"
```

---

## Verification

After all tasks:

1. **Read the complete SKILL.md** end-to-end and verify:
   - The `## Git Commands` section exists between `## Flow` and `## Topic Mode: Step 0b`
   - The section includes correct and incorrect examples with explicit `NEVER` language
   - Step 2 has a brief cross-reference rather than a full explanation
   - The Red Flags "Never" list includes the explicit `cd` prohibition
   - The Red Flags "Always" list has a streamlined `git -C` entry with cross-reference
   - All orchestrator code blocks still use `git -C "$WORKTREE_PATH"`
   - No `cd` commands appear in orchestrator code blocks
   - No `&&` chains appear in orchestrator code blocks
   - No subagent prompts were modified
   - No other sections were accidentally modified

2. **Count all places the `git -C` convention is now reinforced:**
   - `## Git Commands` section (primary, authoritative)
   - Step 2 cross-reference ("see Git Commands section above")
   - Steps 3, 5, 6 code blocks (examples by demonstration)
   - Red Flags "Never" (prohibition of `cd`)
   - Red Flags "Always" (prescription of `git -C`)
   - Total: 5+ independent reinforcements, with the new top-level section as the anchor

3. **Trace the observed failure scenario through the updated logic:**
   - Orchestrator reaches Step 3 and needs to commit the plan
   - Before Step 3, it already read the `## Git Commands` section which says "MUST use `git -C`" with correct/incorrect examples
   - Step 3's code block shows `git -C "$WORKTREE_PATH" add docs/plans/*.md`
   - If the LLM still considers `cd && git`, the "Never" red flag explicitly prohibits `cd` in any form
   - Result: three independent signals (top-level section, code block example, explicit prohibition) all push toward `git -C`
