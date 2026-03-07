# Plan: README "What to Expect" Section

**Issue:** #19 — README: add a "what to expect" section
**Scope:** README.md only. No functionality changes.

## Problem

The README jumps from installation straight to `/lightbulb 42` with no explanation of what actually happens. First-time users are surprised by the multi-phase process.

## Solution

Add a "What to expect" section between the "Skills" description and the "Installation" section. This section provides a brief numbered walkthrough of the lightbulb skill's phases, setting expectations before the user runs it.

## Tasks

### Task 1: Add "What to expect" section to README.md

**Location:** Insert a new `## What to expect` section after the current Skills section (after line 11) and before the `## Installation` section (line 13).

**Content** (from the issue specification):

```markdown
## What to expect

When you run `/lightbulb 42`, the skill will:

1. Fetch the issue and create an isolated git worktree
2. Brainstorm a design and write an implementation plan
3. Implement the plan via subagents
4. Open a draft PR and run review rounds
5. Check CI and ask you how to finish (mark ready or merge)
```

**Verification:** Read the file after editing to confirm correct placement and formatting.

## Notes

- Single-file change (README.md)
- No code, tests, or configuration changes needed
- Content is specified verbatim in the issue
