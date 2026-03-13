# around

Custom [Claude Code](https://claude.com/claude-code) skills.

## Skills

### lightbulb

End-to-end autonomous development from a GitHub issue or a topic/idea. Takes an issue number -- or a plain-text idea that it brainstorms into an issue automatically -- and drives the full workflow: planning, implementation, code review, and PR creation, all via subagents in an isolated git worktree.

**Flow:** fetch issue -> brainstorm design -> write plan -> implement (via SDD) -> create draft PR -> review loop -> CI check -> mark ready or merge

## What to expect

When you run `/lightbulb 42`, the skill will:

1. Fetch the issue and create an isolated git worktree
2. Brainstorm a design and write an implementation plan
3. Implement the plan via subagents
4. Open a draft PR and run review rounds
5. Check CI and ask you how to finish (mark ready or merge)

## Installation

### Symlink (recommended)

Clone this repo and symlink the skills you want into your Claude Code skills directory:

```bash
git clone git@github.com:fumb13s/around.git ~/around

# Install lightbulb skill
mkdir -p ~/.claude/skills
ln -s ~/around/skills/lightbulb ~/.claude/skills/lightbulb
```

### Copy

Or copy the skill directory directly:

```bash
cp -r skills/lightbulb ~/.claude/skills/lightbulb
```

### Per-project

To make a skill available only in a specific project, symlink or copy into the project's `.claude/skills/` directory instead:

```bash
mkdir -p /path/to/project/.claude/skills
ln -s ~/around/skills/lightbulb /path/to/project/.claude/skills/lightbulb
```

## Dependencies

The lightbulb skill delegates to these [superpowers](https://github.com/obra/superpowers) skills:

- `superpowers:using-git-worktrees` -- worktree setup
- `superpowers:brainstorming` -- design exploration
- `superpowers:writing-plans` -- plan creation
- `superpowers:subagent-driven-development` -- implementation

Make sure the superpowers plugin is installed in your Claude Code instance.

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
      "Bash(git -C * check-ignore *)",
      "Bash(git -C * worktree add *)",
      "Bash(git -C * add *)",
      "Bash(git -C * commit *)",
      "Bash(git -C * push *)",
      "Bash(git -C * diff *)",
      "Bash(git -C * symbolic-ref *)",
      "Bash(git -C * rev-parse *)",
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
      "Bash(gh pr merge *)",
      "Edit(*)",
      "Write(*)",
      "Bash(chmod *)",
      "Bash(bash *)",
      "Bash(grep *)",
      "Bash(sed *)",
      "Bash(jq *)",
      "Bash(which *)",
      "Bash(find *)",
      "Bash(export *)"
    ]
  }
}
```

These patterns cover all commands the lightbulb orchestrator and its worktree setup phase execute. They use specific command prefixes rather than broad wildcards to limit the scope of auto-approval.

## Usage

### Issue mode

Provide a GitHub issue number to develop an existing issue end-to-end:

```
/lightbulb 42
```

Or just tell Claude: "implement issue #42" -- the skill triggers when a GitHub issue number is provided with intent for autonomous development.

### Topic mode

Provide a topic or idea instead of an issue number. The skill will brainstorm a design, file it as a GitHub issue, and then develop it end-to-end:

```
/lightbulb add a changelog that auto-generates from PR titles
```

Or in natural language: "build a retry mechanism for flaky API calls" -- the skill detects that no issue number was given and enters topic mode automatically.

### Options

Set max review rounds (default 5) in natural language:

```
implement issue #42 with at most 3 review rounds
```
