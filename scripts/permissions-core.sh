#!/usr/bin/env bash
# permissions-core.sh -- shared logic for skill permission setup scripts
#
# Sourced by per-skill wrappers after they set:
#   SKILL_NAME      display name (e.g. "lightbulb")
#   SCRIPT_VERSION  version string (e.g. "3")
#   VERSION_KEY     settings JSON key (e.g. "_lightbulb_permissions_version")
#   SKILL_RULES     bash array of permission rules

set -euo pipefail

# --- argument parsing ---

show_usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Adds ${SKILL_NAME} skill permission entries to Claude Code settings.

Options:
  --project       Patch .claude/settings.local.json in the current project
                  instead of the global ~/.claude/settings.json
  --check         Show current state without making changes
  --remove        Remove ${SKILL_NAME} permission entries
  -h, --help      Show this help message

By default, patches ~/.claude/settings.json (global).
USAGE
}

MODE="install"
SETTINGS_FILE="$HOME/.claude/settings.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      SETTINGS_FILE=".claude/settings.local.json"
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
      show_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_usage >&2
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

build_jq_add_filter() {
  local filter=''
  filter=".permissions.${VERSION_KEY} = \"${SCRIPT_VERSION}\""
  for rule in "${SKILL_RULES[@]}"; do
    filter="${filter} | if (.permissions.allow // [] | index(\"${rule}\")) then . else .permissions.allow = ((.permissions.allow // []) + [\"${rule}\"]) end"
  done
  echo "$filter"
}

build_jq_remove_filter() {
  local filter=''
  filter="del(.permissions.${VERSION_KEY})"
  for rule in "${SKILL_RULES[@]}"; do
    filter="${filter} | .permissions.allow = ((.permissions.allow // []) - [\"${rule}\"])"
  done
  filter="${filter} | if (.permissions.allow | length) == 0 then del(.permissions.allow) else . end"
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
    echo "Status: ${SKILL_NAME} permissions NOT installed"
  elif [[ "$current_version" == "$SCRIPT_VERSION" ]]; then
    echo "Status: ${SKILL_NAME} permissions installed (version $current_version, up to date)"
  else
    echo "Status: ${SKILL_NAME} permissions installed (version $current_version, update available: $SCRIPT_VERSION)"
  fi

  echo ""
  echo "Checking individual rules:"
  local allow_array
  allow_array=$(jq -r '.permissions.allow // [] | .[]' "$SETTINGS_FILE" 2>/dev/null || echo "")
  local missing=0
  for rule in "${SKILL_RULES[@]}"; do
    if echo "$allow_array" | grep -qF "$rule"; then
      echo "  [ok] $rule"
    else
      echo "  [missing] $rule"
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    echo ""
    echo "All ${#SKILL_RULES[@]} rules present."
  else
    echo ""
    echo "$missing of ${#SKILL_RULES[@]} rules missing."
  fi
}

do_install() {
  local current_version
  current_version=$(read_current_version)

  if [[ "$current_version" == "$SCRIPT_VERSION" ]]; then
    echo "${SKILL_NAME^} permissions already at version $SCRIPT_VERSION in $SETTINGS_FILE"
    echo "Run with --check to verify individual rules, or --remove then re-run to reinstall."
    exit 0
  fi

  if [[ "$current_version" != "0" ]]; then
    echo "Updating ${SKILL_NAME} permissions from version $current_version to $SCRIPT_VERSION..."
    local remove_filter
    remove_filter=$(build_jq_remove_filter)
    TMPFILE=$(mktemp)
    jq "$remove_filter" "$SETTINGS_FILE" > "$TMPFILE" && mv "$TMPFILE" "$SETTINGS_FILE"
  fi

  local add_filter
  add_filter=$(build_jq_add_filter)
  TMPFILE=$(mktemp)
  jq "$add_filter" "$SETTINGS_FILE" > "$TMPFILE" && mv "$TMPFILE" "$SETTINGS_FILE"

  echo "Installed ${SKILL_NAME} permissions (version $SCRIPT_VERSION) in $SETTINGS_FILE"
  echo ""
  echo "${#SKILL_RULES[@]} permission rules added."
  echo "${SKILL_NAME^} skill commands will no longer prompt for approval."
}

do_remove() {
  local current_version
  current_version=$(read_current_version)

  if [[ "$current_version" == "0" ]]; then
    echo "No ${SKILL_NAME} permissions found in $SETTINGS_FILE"
    exit 0
  fi

  local remove_filter
  remove_filter=$(build_jq_remove_filter)
  TMPFILE=$(mktemp)
  jq "$remove_filter" "$SETTINGS_FILE" > "$TMPFILE" && mv "$TMPFILE" "$SETTINGS_FILE"

  echo "Removed ${SKILL_NAME} permissions from $SETTINGS_FILE"
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
