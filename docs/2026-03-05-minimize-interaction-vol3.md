# Minimize Unnecessary Human Interaction Vol. 3 -- Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add permission entries for additional shell commands (`chmod`, `bash -n`, `grep`, `sed`, `jq`, `which`, `find`, `export`) used by the lightbulb orchestrator and its subagents, so they no longer trigger interactive approval prompts.

**Architecture:** Three files need updating: (1) `scripts/setup-permissions.sh` -- add the new rules to the `LIGHTBULB_RULES` array and bump `SCRIPT_VERSION` to `"2"` so existing installs detect the update; (2) `README.md` -- add the new entries to the manual setup JSON block; (3) no SKILL.md changes needed (the red flag about permission coverage already exists from vol2).

**Tech Stack:** Bash (setup script), Markdown (docs), JSON (Claude Code settings)

---

## Background

Vol. 2 added permission entries for `git`, `gh`, `Edit`, and `Write` commands. In practice, the orchestrator and its subagents also use standard Unix utilities that still trigger prompts:

| Command | Use Case | Proposed Pattern |
|---------|----------|------------------|
| `chmod` | Making scripts executable (e.g., `chmod +x scripts/*.sh`) | `Bash(chmod *)` |
| `bash -n` | Syntax-checking shell scripts before committing | `Bash(bash -n *)` |
| `bash` (standalone) | Running scripts (e.g., `bash scripts/setup-permissions.sh --check`) | `Bash(bash *)` |
| `grep` | Searching code in repo and /tmp for patterns | `Bash(grep *)` |
| `sed` | Text processing / in-place edits from subagents | `Bash(sed *)` |
| `jq` | Parsing JSON output (e.g., from `gh` commands) | `Bash(jq *)` |
| `which` | Checking if a tool is installed | `Bash(which *)` |
| `find` | Finding files in the repo/worktree | `Bash(find *)` |
| `export` | Setting env vars before running commands | `Bash(export *)` |

**Why `bash *` instead of just `bash -n *`:** The issue specifically mentions `bash -n` for syntax checking, but subagents also run scripts with plain `bash` (e.g., running the setup script during testing). The pattern `Bash(bash *)` covers both `bash -n file.sh` and `bash script.sh`. However, this is a broad pattern. We will add both `Bash(bash *)` to cover general usage and note that `bash -n` is a subset.

**Why `sed` is safe:** The issue had a `(?)` next to sed, but since `Edit(*)` and `Write(*)` are already allowed (which permit arbitrary file modifications), `sed` does not expand the threat surface.

**Version bump rationale:** The setup script uses a `_lightbulb_permissions_version` key to track which version of rules is installed. Bumping from `"1"` to `"2"` ensures that users who previously ran the script will see "update available" on `--check` and get the new rules on re-run. The update path (remove old, add new) preserves any user-added rules outside the lightbulb set.

---

## Task 1: Add new permission rules to setup-permissions.sh

**Files:**
- Modify: `scripts/setup-permissions.sh`

### Step 1: Bump the script version

In `scripts/setup-permissions.sh`, find line 8:

```
SCRIPT_VERSION="1"
```

Replace with:

```
SCRIPT_VERSION="2"
```

### Step 2: Add the new rules to the LIGHTBULB_RULES array

In `scripts/setup-permissions.sh`, find the `LIGHTBULB_RULES` array (lines 11-32). Add the following 8 new entries after the existing `'Write(*)'` entry (line 31) and before the closing `)` (line 32):

```bash
  'Bash(chmod *)'
  'Bash(bash *)'
  'Bash(grep *)'
  'Bash(sed *)'
  'Bash(jq *)'
  'Bash(which *)'
  'Bash(find *)'
  'Bash(export *)'
```

The complete array should now have 29 entries (21 existing + 8 new).

### Step 3: Verify the script syntax

Run:

```bash
bash -n scripts/setup-permissions.sh
```

Expected: no output (no syntax errors).

### Step 4: Verify the rule count

Run:

```bash
grep -c "Bash\|Edit\|Write" scripts/setup-permissions.sh | head -1
```

Or more precisely, count the array elements:

```bash
grep -c "^  '" scripts/setup-permissions.sh
```

Expected: `29`

### Step 5: Commit

```bash
git add scripts/setup-permissions.sh
git commit -m "feat: add permission rules for chmod, bash, grep, sed, jq, which, find, export

Bump SCRIPT_VERSION to 2 so existing installs detect the update.
These commands are used by the orchestrator and subagents for
script validation, text processing, and file discovery."
```

---

## Task 2: Update README.md manual setup section

**Files:**
- Modify: `README.md`

### Step 1: Add new entries to the permissions JSON block

In `README.md`, find the manual setup JSON block (lines 87-114). Add the 8 new entries after the `"Write(*)"` line (line 110) and before the closing `]` (line 111).

The new entries to add (with appropriate JSON formatting -- note the comma after `"Write(*)"` and on each new line except the last):

```json
      "Bash(chmod *)",
      "Bash(bash *)",
      "Bash(grep *)",
      "Bash(sed *)",
      "Bash(jq *)",
      "Bash(which *)",
      "Bash(find *)",
      "Bash(export *)"
```

Make sure the previously last entry `"Write(*)"` now has a trailing comma.

### Step 2: Verify the JSON block

Count the entries in the allow array. Expected: 29 entries total.

Also verify the JSON is valid by visually checking that all commas are correct (every line has a trailing comma except the last entry before `]`).

### Step 3: Commit

```bash
git add README.md
git commit -m "docs: add new permission entries to manual setup section"
```

---

## Task 3: Test the updated setup script

**Files:**
- Read: `scripts/setup-permissions.sh`

### Step 1: Test fresh install

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{}' > "$TMPDIR/.claude/settings.json"
cd "$TMPDIR"
SCRIPT_PATH="/home/maurezen/git_tree/around/.worktrees/feature/issue-12-minimize-interaction-vol3/scripts/setup-permissions.sh"
"$SCRIPT_PATH" --project
cat "$TMPDIR/.claude/settings.json" | jq '.permissions.allow | length'
cd -
rm -rf "$TMPDIR"
```

Expected: `29` (the total number of permission rules).

### Step 2: Test version upgrade path

Simulate having version 1 installed, then running the version 2 script:

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
cat > "$TMPDIR/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "_lightbulb_permissions_version": "1",
    "allow": [
      "Bash(gh issue view *)",
      "Bash(gh issue create *)",
      "Bash(echo *)",
      "Bash(custom-user-rule *)"
    ]
  }
}
JSON
cd "$TMPDIR"
SCRIPT_PATH="/home/maurezen/git_tree/around/.worktrees/feature/issue-12-minimize-interaction-vol3/scripts/setup-permissions.sh"
"$SCRIPT_PATH" --project
echo "--- Version after upgrade ---"
jq -r '.permissions._lightbulb_permissions_version' "$TMPDIR/.claude/settings.json"
echo "--- Total allow entries ---"
jq '.permissions.allow | length' "$TMPDIR/.claude/settings.json"
echo "--- Custom rule preserved? ---"
jq '.permissions.allow | index("Bash(custom-user-rule *)")' "$TMPDIR/.claude/settings.json"
cd -
rm -rf "$TMPDIR"
```

Expected:
- Version: `2`
- Total entries: `30` (29 lightbulb rules + 1 custom user rule)
- Custom rule preserved: a number (not `null`)

### Step 3: Test --check with version 2

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{}' > "$TMPDIR/.claude/settings.json"
cd "$TMPDIR"
SCRIPT_PATH="/home/maurezen/git_tree/around/.worktrees/feature/issue-12-minimize-interaction-vol3/scripts/setup-permissions.sh"
"$SCRIPT_PATH" --project
"$SCRIPT_PATH" --project --check
cd -
rm -rf "$TMPDIR"
```

Expected: all 29 rules show `[ok]`, status shows "up to date", version 2.

### Step 4: Test --remove

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{}' > "$TMPDIR/.claude/settings.json"
cd "$TMPDIR"
SCRIPT_PATH="/home/maurezen/git_tree/around/.worktrees/feature/issue-12-minimize-interaction-vol3/scripts/setup-permissions.sh"
"$SCRIPT_PATH" --project
"$SCRIPT_PATH" --project --remove
cat "$TMPDIR/.claude/settings.json"
cd -
rm -rf "$TMPDIR"
```

Expected: after remove, settings file is back to `{}`.

### Step 5: Fix any issues found during testing

If any test fails, go back and fix the script or README, then re-run failing tests. Do not proceed until all tests pass.

---

## Verification

After all tasks:

1. **Read `scripts/setup-permissions.sh`** and verify:
   - `SCRIPT_VERSION` is `"2"`
   - `LIGHTBULB_RULES` array has exactly 29 entries
   - The 8 new entries are: `chmod`, `bash`, `grep`, `sed`, `jq`, `which`, `find`, `export`
   - Array syntax is correct (each entry is single-quoted, no trailing commas in bash arrays)

2. **Read `README.md`** and verify:
   - The manual setup JSON block has exactly 29 entries in the `allow` array
   - JSON syntax is valid (commas between entries, no trailing comma before `]`)
   - The 8 new entries match the script entries exactly

3. **Cross-check the new rules against the issue's command list:**
   - `chmod` on a file in the repo -> `Bash(chmod *)`
   - `bash -n` on a file in the repo -> `Bash(bash *)` (covers `bash -n` and general `bash`)
   - `grep` within the repo and /tmp -> `Bash(grep *)`
   - `sed` -> `Bash(sed *)`
   - `jq` -> `Bash(jq *)`
   - `which` -> `Bash(which *)`
   - `find` in the repo/worktree -> `Bash(find *)`
   - `export` -> `Bash(export *)`

4. **Verify the upgrade path works:** The version bump from 1 to 2 means:
   - Fresh installs get all 29 rules at version 2
   - Existing version 1 installs see "update available" on `--check`
   - Running the script again removes old version 1 rules and installs all 29 version 2 rules
   - User-added rules outside the lightbulb set are preserved during upgrade
