#!/usr/bin/env bash
# Usage skill -- permission setup

SKILL_NAME="usage"
SCRIPT_VERSION="4"
VERSION_KEY="_usage_permissions_version"

SKILL_RULES=(
  'Bash(npx ccusage@latest *)'
  'Bash(python3 */aggregate.py *)'
  'Write(/tmp/ccusage-output.json)'
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/permissions-core.sh"
