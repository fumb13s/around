# around

Custom [Claude Code](https://claude.com/claude-code) skills.

## Installation

### Symlink (recommended)

Clone this repo and symlink the skills you want into your Claude Code skills directory:

```bash
git clone git@github.com:fumb13s/around.git ~/around

mkdir -p ~/.claude/skills
ln -s ~/around/skills/lightbulb ~/.claude/skills/lightbulb
ln -s ~/around/skills/usage ~/.claude/skills/usage
```

### Copy

Or copy the skill directories directly:

```bash
cp -r skills/lightbulb ~/.claude/skills/lightbulb
cp -r skills/usage ~/.claude/skills/usage
```

### Per-project

To make a skill available only in a specific project, symlink or copy into the project's `.claude/skills/` directory instead:

```bash
mkdir -p /path/to/project/.claude/skills
ln -s ~/around/skills/lightbulb /path/to/project/.claude/skills/lightbulb
ln -s ~/around/skills/usage /path/to/project/.claude/skills/usage
```

### Permissions

Skills run shell commands that require Claude Code permission approval. Without pre-approved permissions, each command triggers an interactive prompt. Each skill has its own setup script:

```bash
~/around/scripts/setup-permissions.sh                        # lightbulb
~/around/skills/usage/scripts/setup-skill-permissions.sh     # usage
```

Both scripts accept `--project` (per-project instead of global), `--check` (show status), and `--remove`.

---

## lightbulb

End-to-end autonomous development from a GitHub issue or a topic/idea. Takes an issue number -- or a plain-text idea that it brainstorms into an issue automatically -- and drives the full workflow: planning, implementation, code review, and PR creation, all via subagents in an isolated git worktree.

**Flow:** fetch issue -> brainstorm design -> write plan -> implement (via SDD) -> create draft PR -> review loop -> CI check -> mark ready or merge

### What to expect

When you run `/lightbulb 42`, the skill will:

1. Fetch the issue and create an isolated git worktree
2. Brainstorm a design and write an implementation plan
3. Implement the plan via subagents
4. Open a draft PR and run review rounds
5. Check CI and ask you how to finish (mark ready or merge)

### Invocation

#### Issue mode

Provide a GitHub issue number to develop an existing issue end-to-end:

```
/lightbulb 42
```

Or just tell Claude: "implement issue #42" -- the skill triggers when a GitHub issue number is provided with intent for autonomous development.

#### Topic mode

Provide a topic or idea instead of an issue number. The skill will brainstorm a design, file it as a GitHub issue, and then develop it end-to-end:

```
/lightbulb add a changelog that auto-generates from PR titles
```

Or in natural language: "build a retry mechanism for flaky API calls" -- the skill detects that no issue number was given and enters topic mode automatically.

#### Options

Set max review rounds (default 5) in natural language:

```
implement issue #42 with at most 3 review rounds
```

### Dependencies

Delegates to these [superpowers](https://github.com/obra/superpowers) skills:

- `superpowers:brainstorming` -- design exploration
- `superpowers:writing-plans` -- plan creation
- `superpowers:subagent-driven-development` -- implementation

Make sure the superpowers plugin is installed in your Claude Code instance.

---

## usage

Show Claude Code token usage, costs, and billing breakdown. Wraps [`ccusage`](https://github.com/ryoppippi/ccusage) with an aggregation script that produces compact daily and per-project summaries.

### What it does

Fetches token usage data via `ccusage`, aggregates it with a bundled Python script, and presents a summary table with output tokens, cache reads/writes, totals, and API-equivalent cost.

### Invocation

```
/usage
```

Or ask in natural language: "how much am I using?", "which project costs the most?", "what's my usage this week?"

### Views

| View | When to use |
|------|-------------|
| Daily (default) | Recent trends |
| Weekly | Longer-term patterns |
| Session | Per-conversation breakdown |
| Blocks | Billing period / burn rate |

Add per-project breakdown, single-project filter, or model-specific cost split as needed.

### Dependencies

- [`ccusage`](https://github.com/ryoppippi/ccusage) -- installed on demand via `npx`
- Python 3 -- for the aggregation script
