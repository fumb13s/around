# Move plan docs to docs/plans/ subdirectory

## Context

Issue #20: The `docs/` directory accumulates implementation plan files from every issue. These are valuable decision records but mixing them at the top level of `docs/` makes it hard to distinguish them from any future user-facing documentation.

## Tasks

### Task 1: Create docs/plans/ directory and move existing plan files

Move all 11 existing plan files from `docs/` to `docs/plans/`:

- `2026-03-03-fold-issue-creation-design.md`
- `2026-03-03-fold-issue-creation.md`
- `2026-03-03-lightbulb-skill-design.md`
- `2026-03-03-lightbulb-skill.md`
- `2026-03-04-merge-mark-ready.md`
- `2026-03-04-merge-twice-fix.md`
- `2026-03-04-minimize-interaction-vol2.md`
- `2026-03-04-minimize-interaction.md`
- `2026-03-04-stricter-review.md`
- `2026-03-05-minimize-interaction-vol3.md`
- `2026-03-05-no-out-of-scope.md`

Use `git mv` to preserve history.

### Task 2: Update SKILL.md plan output path

In `skills/lightbulb/SKILL.md`, update references from `docs/YYYY-MM-DD-<topic>.md` to `docs/plans/YYYY-MM-DD-<topic>.md`:

1. Line 135: Change `docs/YYYY-MM-DD-<topic>.md` to `docs/plans/YYYY-MM-DD-<topic>.md` in the planning subagent prompt
2. Line 150: Change `git add docs/*.md` to `git add docs/plans/*.md` in the commit command
3. Line 109: Change `docs/brainstorm-<slug>.md` to `docs/plans/brainstorm-<slug>.md` in the error handling section

### Task 3: Move this plan file to docs/plans/ as well

This plan file itself should also be placed in `docs/plans/` to be consistent with the new structure.

## Acceptance Criteria

- All existing plan files are in `docs/plans/`
- No plan files remain in `docs/` root
- SKILL.md references `docs/plans/` for new plan output
- Git history is preserved via `git mv`
