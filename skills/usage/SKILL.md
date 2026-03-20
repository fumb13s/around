---
name: usage
description: >
  Use when the user asks about Claude Code token usage, costs, billing,
  or how much they've been using. Also use when the user wants to understand
  which projects or sessions are consuming the most tokens.
---

# Usage

Show Claude Code token usage via `ccusage` and the aggregation script in this skill's directory.

## Quick Reference

| View | Command | When to use |
|------|---------|-------------|
| Daily | `npx ccusage@latest daily --json --since YYYYMMDD` | Default view, recent trends |
| Weekly | `npx ccusage@latest weekly --json --since YYYYMMDD` | Longer-term patterns |
| Session | `npx ccusage@latest session --json --since YYYYMMDD` | Per-conversation breakdown |
| Blocks | `npx ccusage@latest blocks --json --since YYYYMMDD` | Billing period / burn rate |
| By project | Add `--instances` to any command | Per-project breakdown |
| Single project | Add `--project <name>` | Filter to one project |
| Model detail | Add `--breakdown` | Per-model cost split |

## How to Use

1. **Always use `ccusage`** — never manually parse `~/.claude/projects/` JSONL files
2. **Always use `--json`** for structured data you can summarize
3. **Default to last 7 days** (`--since` with date 7 days ago) unless the user asks for a different range
4. **Start with `daily --instances`** as the default view — it shows per-project daily totals, which answers most questions
5. **Add `--breakdown`** if the user asks about model-specific costs
6. **Call ccusage once, save to a temp file, then process** — never call ccusage twice for the same data

## Workflow

```bash
# 1. Fetch data once into a temp file
npx ccusage@latest daily --json --instances --since YYYYMMDD 2>/dev/null > /tmp/ccusage-output.json

# 2. Aggregate with the script (from this skill's base directory)
python3 <skill-base-dir>/scripts/aggregate.py /tmp/ccusage-output.json
```

The aggregate script handles both `--instances` output (projects → days) and flat output (days/sessions array). It produces compact daily and per-project summaries ready to present.

By default, worktree sessions (spawned by hivemind) are rolled up into `project--hivemind-agents`. If the user asks for per-issue detail, add `--expand-worktrees`:

```bash
python3 <skill-base-dir>/scripts/aggregate.py --expand-worktrees /tmp/ccusage-output.json
```

## Presenting Results

Summarize into a readable table. Key columns:

- **Date** (or session/project name)
- **Output tokens** — the main consumption driver on subscription plans
- **Cache read tokens** — large but cheap; note the ratio
- **Cache write tokens** — prompt cache creation; more expensive than reads
- **Total tokens**
- **Cost (USD)** — API-equivalent cost from ccusage pricing data

Always note: cost shown is API-equivalent pricing. Subscription plans don't map 1:1 to these numbers, but they're useful for relative comparison between days/projects/sessions.

## Common Queries

**"How much am I using?"** — `daily --json --instances` last 7 days, summarize trend

**"Which project uses the most?"** — `daily --json --instances` last 7-14 days, aggregate by project

**"What's eating my quota?"** — `blocks --json` last few days, show billing blocks with token counts

**"How does today compare?"** — `daily --json` last 3-5 days, highlight today vs average
