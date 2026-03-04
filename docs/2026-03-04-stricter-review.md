# Stricter Review — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the lightbulb skill's review phase reject implementations that have Important or Critical issues, preventing false approvals like the one observed in PR #3.

**Architecture:** Two-layer fix in `skills/lightbulb/SKILL.md`. Layer 1: add an explicit status-determination rule to the reviewer prompt so the subagent knows it MUST return NEEDS_FIXES when Critical or Important issues exist. Layer 2: add orchestrator-side validation that parses the issue counts from the review output and overrides an incorrect APPROVED status.

**Tech Stack:** Claude Code skill (Markdown), no code dependencies.

---

## Task 1: Add explicit status rule to reviewer prompt

**Files:**
- Modify: `skills/lightbulb/SKILL.md` (lines 156-165, inside the reviewer subagent prompt blockquote)

### Step 1: Add the status-determination rule

In `skills/lightbulb/SKILL.md`, find the reviewer prompt's category definitions (lines 156-159) and the format block that follows. Insert a mandatory status rule between the category definitions and the format block.

Replace this exact text (lines 156-180):

```
> Categorize each issue as:
> - **Critical:** Must fix — bugs, security issues, missing requirements
> - **Important:** Should fix — poor patterns, missing tests, unclear code
> - **Cosmetic:** Nice to have — style, naming, minor improvements
>
> Return your review in this format:
>
> ```
> REVIEW_RESULT:
> Status: APPROVED | NEEDS_FIXES
> Critical: <count>
> Important: <count>
> Cosmetic: <count>
>
> ## Issues
> ### Critical
> - ...
> ### Important
> - ...
> ### Cosmetic
> - ...
>
> ## Strengths
> - ...
> ```
```

With this text:

```
> Categorize each issue as:
> - **Critical:** Must fix — bugs, security issues, missing requirements
> - **Important:** Should fix — poor patterns, missing tests, unclear code
> - **Cosmetic:** Nice to have — style, naming, minor improvements
>
> **Status rule — follow strictly:**
> - If Critical > 0 OR Important > 0 → Status MUST be `NEEDS_FIXES`
> - If Critical = 0 AND Important = 0 → Status MUST be `APPROVED`
> - Never approve when Important or Critical issues exist, regardless of their severity relative to the overall quality
>
> Return your review in this format:
>
> ```
> REVIEW_RESULT:
> Status: APPROVED | NEEDS_FIXES
> Critical: <count>
> Important: <count>
> Cosmetic: <count>
>
> ## Issues
> ### Critical
> - ...
> ### Important
> - ...
> ### Cosmetic
> - ...
>
> ## Strengths
> - ...
> ```
```

### Step 2: Verify the edit reads correctly

Run: `grep -n "Status rule" skills/lightbulb/SKILL.md`

Expected: one match on the line containing `**Status rule — follow strictly:**`.

### Step 3: Commit

```
fix(lightbulb): add explicit status rule to reviewer prompt

The reviewer prompt now mandates NEEDS_FIXES when any Critical or
Important issues exist. Previously the reviewer had discretion over
the status, which led to false approvals (observed in PR #3).
```

---

## Task 2: Add orchestrator-side status validation

**Files:**
- Modify: `skills/lightbulb/SKILL.md` (between the "Post the review" step and the "If Status is NEEDS_FIXES" step — between current lines 188 and 190)

### Step 1: Insert the validation step

In `skills/lightbulb/SKILL.md`, find the text block for posting the review as a PR comment (step 4 of the review loop) and the subsequent decision logic (steps 5-6). Insert a new step between them.

Replace this exact text (lines 188-190):

```
— Claude"
```

5. **If Status is NEEDS_FIXES** (critical or important issues):
```

With this text:

```
— Claude"
```

5. **Validate the reviewer's status.** Parse the `Critical:` and `Important:` counts from the `REVIEW_RESULT` block. If either count is greater than 0 but the reviewer returned `Status: APPROVED`, override the status to `NEEDS_FIXES` and log: "Overriding reviewer status: found N critical and M important issues but reviewer returned APPROVED."

   This is a safety net — the reviewer prompt (Task 1) should already produce the correct status, but the orchestrator enforces the rule independently.

6. **If Status is NEEDS_FIXES** (critical or important issues):
```

### Step 2: Renumber the remaining steps

The old steps 5, 6, 7 become 6, 7, 8. Find and update these references in the review loop section:

- Old step 6 ("If Status is APPROVED") becomes step 7
- Old step 7 ("If max rounds reached") becomes step 8

### Step 3: Verify the renumbering

Run: `grep -n "^[0-9]\." skills/lightbulb/SKILL.md | tail -10`

Expected: review loop steps numbered 1 through 8 without gaps or duplicates.

### Step 4: Commit

```
fix(lightbulb): add orchestrator-side status validation

The orchestrator now parses Critical/Important counts from the review
output and overrides an incorrect APPROVED status. This is the second
layer of defense alongside the reviewer prompt rule from the previous
commit.
```

---

## Task 3: Add a "Never" red flag for the new invariant

**Files:**
- Modify: `skills/lightbulb/SKILL.md` (Red Flags section, "Never" list)

### Step 1: Add the red flag

In `skills/lightbulb/SKILL.md`, find the "Never:" list in the Red Flags section. Add a new bullet after "Run more review rounds than the configured max":

```
- Accept an APPROVED review that has Critical or Important issues — always override to NEEDS_FIXES
```

### Step 2: Verify the red flag is present

Run: `grep -n "Accept an APPROVED" skills/lightbulb/SKILL.md`

Expected: one match in the Red Flags section.

### Step 3: Commit

```
fix(lightbulb): add red flag for approving with important issues
```

---

## Verification

After all tasks:

1. **Read the complete SKILL.md** end-to-end and verify:
   - The reviewer prompt contains the explicit status rule with the three bullet points
   - The orchestrator validation step (step 5 of the review loop) describes parsing and overriding
   - Steps in the review loop are numbered 1-8 without gaps
   - The Red Flags section includes the new "Accept an APPROVED" bullet
   - No other sections were accidentally modified

2. **Trace the PR #3 scenario through the updated logic:**
   - Reviewer returns `Status: APPROVED`, `Critical: 0`, `Important: 2`
   - Layer 1 (prompt rule): reviewer should now return `NEEDS_FIXES` instead, since Important > 0
   - Layer 2 (orchestrator validation): even if reviewer still returns APPROVED, orchestrator sees Important = 2 > 0, overrides to NEEDS_FIXES
   - Orchestrator dispatches fixer subagent with the 2 important issues
   - Correct behavior achieved through either layer independently
