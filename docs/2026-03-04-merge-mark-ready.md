# Merge Mark Ready Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the lightbulb skill so that choosing "merge directly" in Step 8 marks the draft PR as ready before merging, and update the menu text to reflect this behavior.

**Architecture:** Single-file text change to `skills/lightbulb/SKILL.md`. Two edits in the Step 8 (Completion) section: update the user-facing menu option text, and add `gh pr ready` before `gh pr merge` in the merge path.

**Tech Stack:** Markdown (SKILL.md instruction file)

---

### Task 1: Update menu option text

**Files:**
- Modify: `skills/lightbulb/SKILL.md:241`

**Step 1: Edit the menu option**

In `skills/lightbulb/SKILL.md`, find line 241 inside the Step 8 blockquote:

```
> 2. Merge directly
```

Replace with:

```
> 2. Mark PR ready and merge directly
```

**Step 2: Verify the edit**

Read `skills/lightbulb/SKILL.md` and confirm line 241 now reads `> 2. Mark PR ready and merge directly`.

---

### Task 2: Add `gh pr ready` before merge command

**Files:**
- Modify: `skills/lightbulb/SKILL.md:244`

**Step 1: Edit the merge instruction**

In `skills/lightbulb/SKILL.md`, find line 244:

```
If merge: `gh pr merge <pr-number> --squash`
```

Replace with:

```
If merge: `gh pr ready <pr-number>` then `gh pr merge <pr-number> --squash`
```

**Step 2: Verify the edit**

Read `skills/lightbulb/SKILL.md` and confirm line 244 now includes both `gh pr ready` and `gh pr merge` commands.

---

### Task 3: Commit the change

**Step 1: Stage and commit**

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): mark draft PR ready before merging in Step 8"
```

**Step 2: Verify the commit**

```bash
git log --oneline -1
```

Expected: commit message starting with `fix(lightbulb): mark draft PR ready before merging in Step 8`.
