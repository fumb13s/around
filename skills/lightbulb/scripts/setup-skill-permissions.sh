#!/usr/bin/env bash
# Lightbulb skill -- permission setup

SKILL_NAME="lightbulb"
SCRIPT_VERSION="5"
VERSION_KEY="_lightbulb_permissions_version"

SKILL_RULES=(
  'Bash(gh issue view *)'
  'Bash(gh issue create *)'
  'Bash(gh label create *)'
  'Bash(git check-ignore *)'
  'Bash(git worktree add *)'
  'Bash(cd *)'
  'Bash(git add *)'
  'Bash(git commit *)'
  'Bash(git push *)'
  'Bash(git diff *)'
  'Bash(git symbolic-ref *)'
  'Bash(echo *)'
  'Bash(gh pr create *)'
  'Bash(gh pr comment *)'
  'Bash(gh pr checks *)'
  'Bash(gh pr ready *)'
  'Bash(gh pr merge *)'
  'Edit(*)'
  'Bash(chmod *)'
  'Bash(grep *)'
  'Bash(sed *)'
  'Bash(jq *)'
  'Bash(which *)'
  'Bash(find *)'
  'Bash(export *)'
)

# Dropped in v4, not renamed: Claude Code matches path-scoped file permissions
# only through the Edit(...) namespace, which already covers Write, Edit and
# NotebookEdit -- so Write(*) never matched anything and the harness now warns
# about it at session start. Edit(*) above already grants what it was meant to.
#
# Bash(BASE=$(git symbolic-ref *) is dropped too: the inner $( is never closed,
# so the rule is malformed and reported as permanently missing by --check.
# Bash(git symbolic-ref *) above covers the command it was reaching for.
#
# Dropped in v5: the eight git -C rules put a wildcard before the subcommand,
# and * matches across spaces, so each one also approved any global options
# slipped in ahead of it -- `git -C . -c core.sshCommand=<cmd> push` runs <cmd>
# (over an ssh remote) with no prompt. Claude Code warns about all eight at
# session start. The worktree paths they served change with every issue, so
# there is no exact value to pin them to; lightbulb's `git -C "$WORKTREE_PATH"`
# commands prompt instead. Bash(bash *) goes too: it approved
# `bash -c '<anything>'`.
SKILL_LEGACY_RULES=(
  'Write(*)'
  'Bash(BASE=$(git symbolic-ref *)'
  'Bash(git -C * check-ignore *)'
  'Bash(git -C * worktree add *)'
  'Bash(git -C * add *)'
  'Bash(git -C * commit *)'
  'Bash(git -C * push *)'
  'Bash(git -C * diff *)'
  'Bash(git -C * symbolic-ref *)'
  'Bash(git -C * rev-parse *)'
  'Bash(bash *)'
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/permissions-core.sh"
