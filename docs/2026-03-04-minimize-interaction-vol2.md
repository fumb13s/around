# Minimize Unnecessary Human Interaction Vol. 2 -- Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate permission prompts for the shell commands the lightbulb orchestrator runs during a session by providing a setup script that patches `~/.claude/settings.json` with the correct `permissions.allow` entries, and documenting the permissions in the README.

**Architecture:** Three deliverables: (1) a setup script `scripts/setup-permissions.sh` that patches the user's settings file with specific `Bash(...)` permission patterns for every orchestrator command, using a version marker for future updates; (2) updated README.md with a Permissions section; (3) updated SKILL.md red flags section noting that all orchestrator commands must have matching permission entries.

**Tech Stack:** Bash (setup script), Markdown (docs), JSON (Claude Code settings)

---

## Background

Claude Code's permission system requires explicit approval for each unique Bash command. The `permissionMode: "acceptEdits"` (added in vol1) only auto-approves file edits, not Bash tool invocations. Every shell command the orchestrator runs -- `gh issue view`, `git push`, `gh pr create`, etc. -- triggers a permission prompt.

Claude Code supports glob patterns in `permissions.allow` arrays (e.g., `Bash(git push *)` matches `git push -u origin feature/my-branch`). By pre-approving the specific command patterns the lightbulb skill uses, we eliminate all unnecessary prompts.

### Permission patterns needed

Derived from the commands listed in issue #9 and their occurrences in SKILL.md:

| Pattern | SKILL.md Location | Purpose |
|---------|-------------------|---------|
| `Bash(gh issue view *)` | Step 1 | Fetch issue metadata |
| `Bash(gh issue create *)` | Step 0c | Create issue (topic mode) |
| `Bash(gh label create *)` | Emergent | Create labels for issues |
| `Bash(git check-ignore *)` | Step 2 (worktree skill) | Verify worktree dir is gitignored |
| `Bash(git worktree add *)` | Step 2 (worktree skill) | Create isolated worktree |
| `Bash(cd *)` | Step 2-3 | cd to worktree then operate |
| `Bash(git add *)` | Steps 3, 6 | Stage files |
| `Bash(git commit *)` | Steps 3, 6 | Commit changes |
| `Bash(git push *)` | Steps 5, 6 | Push branch to remote |
| `Bash(git diff *)` | Step 6 | Review diff (standalone or in pipeline) |
| `Bash(git symbolic-ref *)` | Step 6 | Detect base branch (standalone) |
| `Bash(BASE=$(git symbolic-ref *)` | Step 6 | Base-branch-detection compound command |
| `Bash(echo *)` | Step 6 | Diagnostic output in diff pipeline |
| `Bash(gh pr create *)` | Step 5 | Create draft PR |
| `Bash(gh pr comment *)` | Step 6 | Post review comments |
| `Bash(gh pr checks *)` | Step 7 | Check CI status |
| `Bash(gh pr ready *)` | Step 8 | Mark PR ready for review |
| `Bash(gh pr merge *)` | Step 8 | Merge PR |

The base-branch diff in SKILL.md Step 6 appears as a compound command in practice:
```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@') && echo "Base branch: $BASE" && git diff $BASE...HEAD
```
This is covered by `Bash(BASE=$(git symbolic-ref *)` when executed as one compound command, or by the individual `Bash(git symbolic-ref *)`, `Bash(echo *)`, and `Bash(git diff *)` patterns when the orchestrator splits them into separate Bash calls.

---

## Task 1: Create the setup script

**Files:**
- Create: `scripts/setup-permissions.sh`

The script patches `~/.claude/settings.json` (default) or a project-level settings file (`--project`) with the lightbulb permission entries. It uses a `_lightbulb_permissions_version` key to mark the block for future updates.

### Step 1: Create the scripts directory

```bash
mkdir -p scripts
```

### Step 2: Write the setup script

Create `scripts/setup-permissions.sh` with the following content:

```bash
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
    local tmp
    tmp=$(mktemp)
    jq "$remove_filter" "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  fi

  local add_filter
  add_filter=$(build_jq_add_filter)
  local tmp
  tmp=$(mktemp)
  jq "$add_filter" "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"

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
  local tmp
  tmp=$(mktemp)
  jq "$remove_filter" "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"

  echo "Removed lightbulb permissions from $SETTINGS_FILE"
}

# --- main ---

ensure_jq
ensure_settings_file

case "$MODE" in
  check)   do_check ;;
  install) do_install ;;
  remove)  do_remove ;;
esac
```

### Step 3: Make the script executable

```bash
chmod +x scripts/setup-permissions.sh
```

### Step 4: Verify the script syntax

```bash
bash -n scripts/setup-permissions.sh
```

Expected: no output (no syntax errors).

### Step 5: Commit

```bash
git add scripts/setup-permissions.sh
git commit -m "feat: add permission setup script for lightbulb skill"
```

---

## Task 2: Test the setup script

**Files:**
- Read: `scripts/setup-permissions.sh`

### Step 1: Test --help

```bash
scripts/setup-permissions.sh --help
```

Expected: usage text displayed, exit 0.

### Step 2: Test install on an empty settings file

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{}' > "$TMPDIR/.claude/settings.json"
cd "$TMPDIR"
/home/maurezen/git_tree/around/.worktrees/feature/issue-9-minimize-interaction/scripts/setup-permissions.sh --project
cat "$TMPDIR/.claude/settings.json"
cd -
rm -rf "$TMPDIR"
```

Expected: the settings file contains `permissions.allow` with all 18 rules and `_lightbulb_permissions_version: "1"`.

### Step 3: Test idempotency

Run the same install command again on the same file. It should report "already at version" and not duplicate entries.

### Step 4: Test --check

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{}' > "$TMPDIR/.claude/settings.json"
cd "$TMPDIR"
/home/maurezen/git_tree/around/.worktrees/feature/issue-9-minimize-interaction/scripts/setup-permissions.sh --project
/home/maurezen/git_tree/around/.worktrees/feature/issue-9-minimize-interaction/scripts/setup-permissions.sh --project --check
cd -
rm -rf "$TMPDIR"
```

Expected: all 18 rules show `[ok]`.

### Step 5: Test --remove

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{}' > "$TMPDIR/.claude/settings.json"
cd "$TMPDIR"
/home/maurezen/git_tree/around/.worktrees/feature/issue-9-minimize-interaction/scripts/setup-permissions.sh --project
/home/maurezen/git_tree/around/.worktrees/feature/issue-9-minimize-interaction/scripts/setup-permissions.sh --project --remove
cat "$TMPDIR/.claude/settings.json"
cd -
rm -rf "$TMPDIR"
```

Expected: after remove, the settings file is back to `{}` (empty permissions cleaned up).

### Step 6: Test install into existing settings with other permissions

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
cat > "$TMPDIR/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Read(~/.zshrc)"
    ],
    "deny": [
      "Bash(curl *)"
    ]
  }
}
JSON
cd "$TMPDIR"
/home/maurezen/git_tree/around/.worktrees/feature/issue-9-minimize-interaction/scripts/setup-permissions.sh --project
cat "$TMPDIR/.claude/settings.json"
cd -
rm -rf "$TMPDIR"
```

Expected: existing `allow` entries (`Bash(npm run *)`, `Read(~/.zshrc)`) are preserved, lightbulb rules are appended, `deny` array is untouched.

### Step 7: Fix any issues found during testing

If any test fails, fix the script and re-run. Do not proceed until all tests pass.

---

## Task 3: Update README.md with permissions documentation

**Files:**
- Modify: `README.md`

### Step 1: Add Permissions section after Dependencies

In `README.md`, find the line:

```
Make sure the superpowers plugin is installed in your Claude Code instance.
```

After that line, add:

```markdown

## Permissions

The lightbulb skill's orchestrator runs shell commands (`git`, `gh`) that require Claude Code permission approval. Without pre-approved permissions, each command triggers an interactive prompt.

### Quick setup (recommended)

Run the setup script to automatically add the required permissions to your global Claude Code settings:

```bash
~/around/scripts/setup-permissions.sh
```

Or for a specific project only:

```bash
~/around/scripts/setup-permissions.sh --project
```

Other commands:

```bash
# Check current permission status
~/around/scripts/setup-permissions.sh --check

# Remove lightbulb permissions
~/around/scripts/setup-permissions.sh --remove
```

### Manual setup

Add these entries to `permissions.allow` in `~/.claude/settings.json` (global) or `.claude/settings.json` (per-project):

```json
{
  "permissions": {
    "allow": [
      "Bash(gh issue view *)",
      "Bash(gh issue create *)",
      "Bash(gh label create *)",
      "Bash(git check-ignore *)",
      "Bash(git worktree add *)",
      "Bash(cd *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git push *)",
      "Bash(git diff *)",
      "Bash(git symbolic-ref *)",
      "Bash(BASE=$(git symbolic-ref *)",
      "Bash(echo *)",
      "Bash(gh pr create *)",
      "Bash(gh pr comment *)",
      "Bash(gh pr checks *)",
      "Bash(gh pr ready *)",
      "Bash(gh pr merge *)"
    ]
  }
}
```

These patterns cover all commands the lightbulb orchestrator and its worktree setup phase execute. They use specific command prefixes rather than broad wildcards to limit the scope of auto-approval.
```

### Step 2: Verify the edit

Read `README.md` and confirm the Permissions section is present between Dependencies and Usage, and that the JSON block contains all 18 rules.

### Step 3: Commit

```bash
git add README.md
git commit -m "docs: add permissions setup instructions to README"
```

---

## Task 4: Add red flag note about permission coverage to SKILL.md

**Files:**
- Modify: `skills/lightbulb/SKILL.md`

### Step 1: Add a note to the Always list in Red Flags

In `skills/lightbulb/SKILL.md`, find the line:

```
- In topic mode, create the GitHub issue before proceeding to the normal flow — never skip issue creation
```

After that line, add:

```
- Ensure all orchestrator Bash commands have matching entries in the user's `permissions.allow` — see README for the setup script and manual list
```

### Step 2: Verify the edit

Read `skills/lightbulb/SKILL.md` and confirm the new bullet is present in the "Always:" list.

### Step 3: Commit

```bash
git add skills/lightbulb/SKILL.md
git commit -m "fix(lightbulb): add red flag about permission coverage"
```

---

## Verification

After all tasks:

1. **Run the setup script** with `--check` against a fresh settings file and verify all 18 rules are listed.

2. **Run the setup script** with `--project` against a temp directory, then `--remove`, and verify the file is clean.

3. **Read README.md** and verify:
   - The Permissions section exists between Dependencies and Usage
   - Quick setup and manual setup instructions are both present
   - The JSON block lists exactly 18 rules
   - The `--check` and `--remove` commands are documented

4. **Read SKILL.md** and verify:
   - The red flag about permission coverage is present in the "Always:" list

5. **Cross-check the permission patterns against the issue's command list:**
   - `gh issue view` -> `Bash(gh issue view *)`
   - `git check-ignore` -> `Bash(git check-ignore *)`
   - `git worktree add` -> `Bash(git worktree add *)`
   - `cd && git add && git commit` -> `Bash(cd *)`
   - `gh issue create` -> `Bash(gh issue create *)`
   - `gh label create` -> `Bash(gh label create *)`
   - `git add` -> `Bash(git add *)`
   - `git commit` -> `Bash(git commit *)`
   - `git push` -> `Bash(git push *)`
   - `gh pr create` -> `Bash(gh pr create *)`
   - `BASE=$(git symbolic-ref ...) && echo ... && git diff` -> `Bash(BASE=$(git symbolic-ref *)` + `Bash(echo *)` + `Bash(git diff *)` + `Bash(git symbolic-ref *)`
   - `gh pr comment` -> `Bash(gh pr comment *)`
   - `gh pr checks` -> `Bash(gh pr checks *)`
   - `gh pr ready` -> `Bash(gh pr ready *)`
   - `gh pr merge` -> `Bash(gh pr merge *)`
