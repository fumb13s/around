# Merge Twice Fix — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the lightbulb skill's Step 8 (Completion) so that choosing "Mark PR ready and merge directly" executes exactly `gh pr ready` followed by `gh pr merge` — not a double merge.

**Root Cause:** The current Step 8 instructions use ambiguous conditional labels (`If mark ready:` / `If merge:`) that cause the executing LLM to interpret option 2 ("Mark PR ready and merge directly") as: first perform the "mark ready" action (which it reads as the full `gh pr ready` + `gh pr merge` compound), then perform the "merge" action (`gh pr merge` again). The result is two merge attempts, with the second one failing because the PR is already merged.

**Fix:** Rewrite Step 8 to use numbered option labels that directly match the menu choices, eliminating all ambiguity about which commands belong to which option. Each option gets its own clearly delineated command block.

**Architecture:** Single-file text change to `skills/lightbulb/SKILL.md`. One edit in the Step 8 (Completion) section replacing the conditional command instructions.

**Tech Stack:** Markdown (SKILL.md instruction file)

---

## Task 1: Rewrite Step 8 command instructions

**Files:**
- Modify: `skills/lightbulb/SKILL.md` (Step 8: Completion section, lines 317-318)

### Step 1: Replace the conditional instructions

In `skills/lightbulb/SKILL.md`, find lines 317-318 (the conditional command instructions after the menu blockquote):

```
If mark ready: `gh pr ready <pr-number>`
If merge: `gh pr ready <pr-number>` then `gh pr merge <pr-number> --squash`
```

Replace with:

```
**Option 1:** Run `gh pr ready <pr-number>` — marks the draft PR as ready for human review.

**Option 2:** Run `gh pr ready <pr-number>` then `gh pr merge <pr-number> --squash` — marks the PR ready and immediately merges it. Do NOT run merge a second time; the single `gh pr merge` command here is the only merge.
```

This change:
- Uses **Option 1** / **Option 2** labels that directly correspond to the numbered menu choices, removing the ambiguous `If mark ready:` / `If merge:` labels
- Adds an explicit "Do NOT run merge a second time" instruction as a guardrail against double-execution
- Describes what each option does so the LLM understands the intent

### Step 2: Verify the edit

Read `skills/lightbulb/SKILL.md` and confirm:
- The Step 8 section contains `**Option 1:**` and `**Option 2:**` labels
- Option 2 contains exactly one `gh pr merge` command reference
- The "Do NOT run merge a second time" guardrail is present
- No remnants of the old `If mark ready:` / `If merge:` text remain

### Step 3: Commit

```
fix(lightbulb): disambiguate Step 8 options to prevent double merge

The old "If mark ready:" / "If merge:" conditional labels caused the
executing LLM to interpret option 2 as requiring both the "mark ready"
action AND the "merge" action separately, resulting in two merge
attempts. Replaced with explicit "Option 1:" / "Option 2:" labels
that match the numbered menu and added a guardrail instruction.

Fixes #10
```

---

## Verification

After the task:

1. **Read the complete Step 8 section** and verify:
   - The menu blockquote still shows the two numbered options
   - The command instructions use `**Option 1:**` and `**Option 2:**` labels
   - Option 1 has exactly one command: `gh pr ready`
   - Option 2 has exactly two commands: `gh pr ready` then `gh pr merge --squash`
   - The guardrail instruction ("Do NOT run merge a second time") is present
   - No duplicate or leftover conditional text exists

2. **Trace the failure scenario through the updated instructions:**
   - User picks option 2 ("Mark PR ready and merge directly")
   - LLM sees `**Option 2:**` and executes: `gh pr ready <pr-number>` then `gh pr merge <pr-number> --squash`
   - Only one merge command runs
   - PR is merged successfully without a second merge attempt
