#!/usr/bin/env bash
set -euo pipefail

# install.sh -- Install around skills into Claude Code
#
# Symlinks (default) or copies skill directories, then installs
# the matching permissions at the same scope (user or project).

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

show_usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS] [SKILL ...]

Install around skills into Claude Code.

Options:
  --copy          Copy skill directories instead of symlinking
  --project       Install into .claude/skills/ in the current project
                  instead of ~/.claude/skills/ (user-level)
  --remove        Remove installed skills and their permissions
  --check         Show installation status without making changes
  -h, --help      Show this help message

If no skills are specified, all available skills are installed.

Examples:
  $(basename "$0")                    # symlink all skills, user-level
  $(basename "$0") lightbulb          # symlink lightbulb only
  $(basename "$0") --copy --project   # copy all skills, project-level
  $(basename "$0") --remove usage     # remove usage skill
  $(basename "$0") --check            # show status of all skills
USAGE
}

# --- argument parsing ---

MODE="install"
METHOD="symlink"
SCOPE="user"
SKILLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)    METHOD="copy"; shift ;;
    --project) SCOPE="project"; shift ;;
    --remove)  MODE="remove"; shift ;;
    --check)   MODE="check"; shift ;;
    -h|--help) show_usage; exit 0 ;;
    -*)        echo "Unknown option: $1" >&2; show_usage >&2; exit 1 ;;
    *)         SKILLS+=("$1"); shift ;;
  esac
done

# --- discover available skills ---

available_skills=()
for dir in "$REPO_DIR"/skills/*/; do
  [[ -f "$dir/SKILL.md" ]] && available_skills+=("$(basename "$dir")")
done

if [[ ${#SKILLS[@]} -eq 0 ]]; then
  SKILLS=("${available_skills[@]}")
fi

# Validate requested skills
for skill in "${SKILLS[@]}"; do
  if [[ ! -f "$REPO_DIR/skills/$skill/SKILL.md" ]]; then
    echo "Error: unknown skill '$skill'" >&2
    echo "Available skills: ${available_skills[*]}" >&2
    exit 1
  fi
done

# --- target directory ---

if [[ "$SCOPE" == "user" ]]; then
  TARGET_DIR="$HOME/.claude/skills"
else
  TARGET_DIR=".claude/skills"
fi

PERM_FLAG=""
[[ "$SCOPE" == "project" ]] && PERM_FLAG="--project"

# --- modes ---

do_check() {
  echo "Scope: $SCOPE ($TARGET_DIR)"
  echo ""

  for skill in "${SKILLS[@]}"; do
    local dest="$TARGET_DIR/$skill"

    if [[ -L "$dest" ]]; then
      local link_target
      link_target=$(readlink "$dest")
      echo "  $skill: symlinked -> $link_target"
    elif [[ -d "$dest" ]]; then
      echo "  $skill: copied"
    else
      echo "  $skill: not installed"
    fi
  done

  echo ""
  echo "Permissions:"
  for skill in "${SKILLS[@]}"; do
    local perm_script="$REPO_DIR/skills/$skill/scripts/setup-skill-permissions.sh"
    if [[ -x "$perm_script" ]]; then
      bash "$perm_script" --check $PERM_FLAG 2>&1 | sed 's/^/  /'
    else
      echo "  $skill: no permissions script"
    fi
    echo ""
  done
}

do_install() {
  mkdir -p "$TARGET_DIR"

  echo "Installing skills ($METHOD, $SCOPE)..."
  echo ""

  for skill in "${SKILLS[@]}"; do
    local src="$REPO_DIR/skills/$skill"
    local dest="$TARGET_DIR/$skill"

    # Handle existing installation
    if [[ -L "$dest" || -d "$dest" ]]; then
      echo "  $skill: already exists at $dest, skipping"
      continue
    fi

    if [[ "$METHOD" == "symlink" ]]; then
      ln -s "$src" "$dest"
      echo "  $skill: symlinked"
    else
      cp -r "$src" "$dest"
      echo "  $skill: copied"
    fi
  done

  echo ""
  echo "Installing permissions..."
  echo ""

  for skill in "${SKILLS[@]}"; do
    local perm_script="$REPO_DIR/skills/$skill/scripts/setup-skill-permissions.sh"
    if [[ -x "$perm_script" ]]; then
      bash "$perm_script" $PERM_FLAG
    else
      echo "  $skill: no permissions script, skipping"
    fi
    echo ""
  done
}

do_remove() {
  echo "Removing skills..."
  echo ""

  # Remove permissions first (needs the skill dir to find the script)
  for skill in "${SKILLS[@]}"; do
    local perm_script="$REPO_DIR/skills/$skill/scripts/setup-skill-permissions.sh"
    if [[ -x "$perm_script" ]]; then
      bash "$perm_script" --remove $PERM_FLAG
    fi
  done

  echo ""

  # Then remove the skill directories/symlinks
  for skill in "${SKILLS[@]}"; do
    local dest="$TARGET_DIR/$skill"
    if [[ -L "$dest" ]]; then
      rm "$dest"
      echo "  $skill: symlink removed"
    elif [[ -d "$dest" ]]; then
      rm -rf "$dest"
      echo "  $skill: directory removed"
    else
      echo "  $skill: not installed, skipping"
    fi
  done
}

# --- main ---

case "$MODE" in
  check)   do_check ;;
  install) do_install ;;
  remove)  do_remove ;;
esac
