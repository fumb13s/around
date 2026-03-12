# Implementation Plan: Codify no-&&-chains rule in lightbulb skill

**Issue:** #31
**Date:** 2026-03-12

## Problem

The lightbulb orchestrator's SKILL.md prohibits `cd && git` chains but doesn't explicitly prohibit `&&` chains in general for all orchestrator Bash commands. This was observed after merging #28 (which addressed `&&` chains in git commands), when the orchestrator still used `&&` in non-git commands like `gh pr ready && gh pr merge`.

## Tasks

### Task 1: Add a general "Bash Commands" section above the git-specific section

Add a new top-level section **"Orchestrator Bash Commands"** (or similar) that establishes the general rule: never chain commands with `&&` in any orchestrator Bash call. Each command should be its own separate Bash tool call.

This section should:
- State the rule clearly: one command per Bash tool call, no `&&` chains
- Explain why: harder to inspect results, can trigger security prompts, risks running unintended commands
- Give a correct/wrong example using non-git commands (e.g., `gh pr ready` + `gh pr merge`)

### Task 2: Refine the existing "Git Commands (Worktree Convention)" section

Keep the existing git-specific section but:
- Add a cross-reference to the new general section ("In addition to the general no-chains rule above...")
- Focus the git section purely on the `git -C` convention (its original purpose)
- Update the "Wrong" example to also mention `&&` chains between separate git commands (not just `cd && git`)

### Task 3: Update Red Flags

In the **Never** list:
- Add a new entry: "Chain Bash commands with `&&` — run each command as a separate Bash tool call"
- Keep the existing `cd` entry but make it reference the general rule

In the **Always** list:
- Add: "Run each orchestrator Bash command as a separate Bash tool call — never chain with `&&`"

### Task 4: Audit Step 8 (Completion) code blocks

The Step 8 description mentions running `gh pr ready` then `gh pr merge` — ensure the code blocks show these as separate commands, not chained. (Current text already says "Run `gh pr ready <pr-number>` then `gh pr merge <pr-number> --squash`" which could be interpreted either way — make it explicit that these are separate Bash calls.)

## Files to modify

- `skills/lightbulb/SKILL.md` — the only file that needs changes
