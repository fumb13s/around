#!/usr/bin/env bash
# Usage skill -- permission setup

SKILL_NAME="usage"
SCRIPT_VERSION="1"
VERSION_KEY="_usage_permissions_version"

SKILL_RULES=(
  'Bash(npx ccusage@latest *)'
  'Bash(python3 */aggregate.py *)'
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/permissions-core.sh"
