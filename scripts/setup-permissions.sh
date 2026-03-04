#!/usr/bin/env bash
set -euo pipefail

# Lightbulb skill -- permission setup script
# Patches Claude Code settings with permission entries required by the
# lightbulb orchestrator so its shell commands don't trigger prompts.

SCRIPT_VERSION="1"
VERSION_KEY="_lightbulb_permissions_version"

LIGHTBULB_RULES=(
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
  'Bash(BASE=$(git symbolic-ref *)'
  'Bash(echo *)'
  'Bash(gh pr create *)'
  'Bash(gh pr comment *)'
  'Bash(gh pr checks *)'
  'Bash(gh pr ready *)'
  'Bash(gh pr merge *)'
  'Edit(*)'
  'Write(*)'
)

usage() {
  cat <<'USAGE'
Usage: setup-permissions.sh [OPTIONS]

Adds lightbulb skill permission entries to Claude Code settings.

Options:
  --project       Patch .claude/settings.json in the current project
                  instead of the global ~/.claude/settings.json
  --check         Show current state without making changes
  --remove        Remove lightbulb permission entries
  -h, --help      Show this help message

By default, patches ~/.claude/settings.json (global).
USAGE
}

# --- argument parsing ---

MODE="install"
SETTINGS_FILE="$HOME/.claude/settings.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      SETTINGS_FILE=".claude/settings.json"
      shift
      ;;
    --check)
      MODE="check"
      shift
      ;;
    --remove)
      MODE="remove"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# --- helpers ---

ensure_jq() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    echo "Install it with: brew install jq / apt-get install jq / etc." >&2
    exit 1
  fi
}

ensure_settings_file() {
  local dir
  dir=$(dirname "$SETTINGS_FILE")
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' > "$SETTINGS_FILE"
  fi
}

read_current_version() {
  jq -r ".permissions.${VERSION_KEY} // \"0\"" "$SETTINGS_FILE"
}

# Build a jq filter that adds all lightbulb rules to .permissions.allow
build_jq_add_filter() {
  local filter=''
  filter=".permissions.${VERSION_KEY} = \"${SCRIPT_VERSION}\""
  for rule in "${LIGHTBULB_RULES[@]}"; do
    # Only add if not already present
    filter="${filter} | if (.permissions.allow // [] | index(\"${rule}\")) then . else .permissions.allow = ((.permissions.allow // []) + [\"${rule}\"]) end"
  done
  echo "$filter"
}

# Build a jq filter that removes all lightbulb rules from .permissions.allow
build_jq_remove_filter() {
  local filter=''
  filter="del(.permissions.${VERSION_KEY})"
  for rule in "${LIGHTBULB_RULES[@]}"; do
    filter="${filter} | .permissions.allow = ((.permissions.allow // []) - [\"${rule}\"])"
  done
  # Clean up empty allow array
  filter="${filter} | if (.permissions.allow | length) == 0 then del(.permissions.allow) else . end"
  # Clean up empty permissions object
  filter="${filter} | if (.permissions | length) == 0 then del(.permissions) else . end"
  echo "$filter"
}

# --- modes ---

do_check() {
  local current_version
  current_version=$(read_current_version)

  echo "Settings file: $SETTINGS_FILE"
  echo ""

  if [[ "$current_version" == "0" ]]; then
    echo "Status: lightbulb permissions NOT installed"
  elif [[ "$current_version" == "$SCRIPT_VERSION" ]]; then
    echo "Status: lightbulb permissions installed (version $current_version, up to date)"
  else
    echo "Status: lightbulb permissions installed (version $current_version, update available: $SCRIPT_VERSION)"
  fi

  echo ""
  echo "Checking individual rules:"
  local allow_array
  allow_array=$(jq -r '.permissions.allow // [] | .[]' "$SETTINGS_FILE" 2>/dev/null || echo "")
  local missing=0
  for rule in "${LIGHTBULB_RULES[@]}"; do
    if echo "$allow_array" | grep -qF "$rule"; then
      echo "  [ok] $rule"
    else
      echo "  [missing] $rule"
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    echo ""
    echo "All ${#LIGHTBULB_RULES[@]} rules present."
  else
    echo ""
    echo "$missing of ${#LIGHTBULB_RULES[@]} rules missing."
  fi
}

do_install() {
  local current_version
  current_version=$(read_current_version)

  if [[ "$current_version" == "$SCRIPT_VERSION" ]]; then
    echo "Lightbulb permissions already at version $SCRIPT_VERSION in $SETTINGS_FILE"
    echo "Run with --check to verify individual rules, or --remove then re-run to reinstall."
    exit 0
  fi

  if [[ "$current_version" != "0" ]]; then
    echo "Updating lightbulb permissions from version $current_version to $SCRIPT_VERSION..."
    # Remove old entries first, then add new ones
    local remove_filter
    remove_filter=$(build_jq_remove_filter)
    TMPFILE=$(mktemp)
    jq "$remove_filter" "$SETTINGS_FILE" > "$TMPFILE" && mv "$TMPFILE" "$SETTINGS_FILE"
  fi

  local add_filter
  add_filter=$(build_jq_add_filter)
  TMPFILE=$(mktemp)
  jq "$add_filter" "$SETTINGS_FILE" > "$TMPFILE" && mv "$TMPFILE" "$SETTINGS_FILE"

  echo "Installed lightbulb permissions (version $SCRIPT_VERSION) in $SETTINGS_FILE"
  echo ""
  echo "${#LIGHTBULB_RULES[@]} permission rules added."
  echo "The lightbulb skill's orchestrator commands will no longer prompt for approval."
}

do_remove() {
  local current_version
  current_version=$(read_current_version)

  if [[ "$current_version" == "0" ]]; then
    echo "No lightbulb permissions found in $SETTINGS_FILE"
    exit 0
  fi

  local remove_filter
  remove_filter=$(build_jq_remove_filter)
  TMPFILE=$(mktemp)
  jq "$remove_filter" "$SETTINGS_FILE" > "$TMPFILE" && mv "$TMPFILE" "$SETTINGS_FILE"

  echo "Removed lightbulb permissions from $SETTINGS_FILE"
}

# --- main ---

TMPFILE=""
trap 'rm -f "$TMPFILE" 2>/dev/null' EXIT

ensure_jq
ensure_settings_file

case "$MODE" in
  check)   do_check ;;
  install) do_install ;;
  remove)  do_remove ;;
esac
