#!/usr/bin/env bash
# Usage skill -- permission setup

SKILL_NAME="usage"
SCRIPT_VERSION="5"
VERSION_KEY="_usage_permissions_version"

SKILL_RULES=(
  'Bash(npx ccusage@latest *)'
  'Bash(npx ccusage@latest * 2>/dev/null > /tmp/ccusage-output.json)'
  'Bash(python3 */aggregate.py *)'
  'Edit(/tmp/ccusage-output.json)'
)

# v4 used Write(/tmp/ccusage-output.json). Claude Code matches path-scoped file
# permissions only through the Edit(...) namespace -- Edit covers every
# file-editing tool -- so a Write(path) rule never matches anything, and the
# harness now warns about it at session start. The v4 commit also dropped the
# literal-redirect Bash rule on the theory that a `>` redirect is checked purely
# as a file write; both checks can fire, so both rules are carried above.
SKILL_LEGACY_RULES=(
  'Write(/tmp/ccusage-output.json)'
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/permissions-core.sh"
