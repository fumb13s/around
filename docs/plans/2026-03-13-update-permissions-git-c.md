# Plan: Update recommended permissions to include git -C pattern

**Issue:** #36 -- Update recommended permissions to include git -C pattern
**Date:** 2026-03-13

## Problem

The recommended permissions in README.md and `scripts/setup-permissions.sh` include individual `git` command patterns like `Bash(git add *)`, `Bash(git commit *)`, etc. But since #25/#29, the lightbulb skill uses `git -C "$WORKTREE_PATH"` for all orchestrator git commands. Commands like `git -C /path/to/worktree add file` don't match these existing patterns, causing permission denials.

## Solution

Add `Bash(git -C *)` to the recommended permissions. This single pattern covers all `git -C` operations. Keep the individual patterns (e.g., `Bash(git add *)`) since subagents may still use plain git commands when running inside the worktree context.

## Tasks

### Task 1: Update `scripts/setup-permissions.sh`

Add `'Bash(git -C *)'` to the `LIGHTBULB_RULES` array. Place it near the other git entries (after `Bash(git worktree add *)` and before `Bash(cd *)`). Bump `SCRIPT_VERSION` from `"2"` to `"3"`.

### Task 2: Update `README.md`

Add `"Bash(git -C *)"` to the manual permissions list in the README. Place it in the same relative position as in the script (after `git worktree add *` and before `cd *`).

### Task 3: Verify consistency

Ensure the LIGHTBULB_RULES array in the script and the JSON list in the README match exactly.
