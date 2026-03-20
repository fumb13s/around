#!/usr/bin/env bash
# Lightbulb skill -- permission setup

SKILL_NAME="lightbulb"
SCRIPT_VERSION="3"
VERSION_KEY="_lightbulb_permissions_version"

SKILL_RULES=(
  'Bash(gh issue view *)'
  'Bash(gh issue create *)'
  'Bash(gh label create *)'
  'Bash(git check-ignore *)'
  'Bash(git worktree add *)'
  'Bash(git -C * check-ignore *)'
  'Bash(git -C * worktree add *)'
  'Bash(git -C * add *)'
  'Bash(git -C * commit *)'
  'Bash(git -C * push *)'
  'Bash(git -C * diff *)'
  'Bash(git -C * symbolic-ref *)'
  'Bash(git -C * rev-parse *)'
  'Bash(cd *)'
  'Bash(git add *)'
  'Bash(git commit *)'
  'Bash(git push *)'
  'Bash(git diff *)'
  'Bash(git symbolic-ref *)'
  'Bash(BASE=$(git symbolic-ref *)'
  'Bash(echo *)'
  'Bash(gh pr create *)'
  'Bash(gh pr comment *)'
  'Bash(gh pr checks *)'
  'Bash(gh pr ready *)'
  'Bash(gh pr merge *)'
  'Edit(*)'
  'Write(*)'
  'Bash(chmod *)'
  'Bash(bash *)'
  'Bash(grep *)'
  'Bash(sed *)'
  'Bash(jq *)'
  'Bash(which *)'
  'Bash(find *)'
  'Bash(export *)'
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/permissions-core.sh"
