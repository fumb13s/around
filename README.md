# around

Custom [Claude Code](https://claude.com/claude-code) skills.

## Skills

### lightbulb

End-to-end autonomous development from a GitHub issue. Takes an issue number and drives the full workflow: planning, implementation, code review, and PR creation -- all via subagents in an isolated git worktree.

**Flow:** fetch issue -> brainstorm design -> write plan -> implement (via SDD) -> create draft PR -> review loop -> CI check -> mark ready or merge

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

The lightbulb skill delegates to these superpowers skills (bundled with the [superpowers plugin](https://github.com/anthropics/claude-code) for Claude Code):

- `superpowers:using-git-worktrees` -- worktree setup
- `superpowers:brainstorming` -- design exploration
- `superpowers:writing-plans` -- plan creation
- `superpowers:subagent-driven-development` -- implementation

Make sure the superpowers plugin is installed in your Claude Code instance.

## Usage

```
/lightbulb 42
```

Or just tell Claude: "implement issue #42" -- the skill triggers when a GitHub issue number is provided with intent for autonomous development.

Optional: set max review rounds (default 5) in natural language:

```
implement issue #42 with at most 3 review rounds
```
