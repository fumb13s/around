#!/usr/bin/env python3
"""Aggregate ccusage JSON output into compact daily and per-project summaries.

Handles both --instances output ({"projects": {...}}) and flat output ({"daily": [...]}).
"""

import argparse
import json
import re
import sys
from collections import defaultdict


def fmt_tokens(n):
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.1f}B"
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}K"
    return str(n)


# Matches worktree sessions: project--worktrees-issue-N or project--claude-worktrees-*
WORKTREE_RE = re.compile(r"^(.+?)--?(?:claude-)?worktrees-.+$")


def normalize_project_name(raw, expand_worktrees=False):
    """Normalize a ccusage project key into a display name.

    Strips the home-path prefix. Unless expand_worktrees is True,
    rolls worktree sessions into project--hivemind-agents.
    """
    name = raw.replace("-home-maurezen-git-tree-", "")
    # Also handle bare home prefix without git_tree
    name = re.sub(r"^-home-maurezen-", "", name)
    if not expand_worktrees:
        m = WORKTREE_RE.match(name)
        if m:
            name = f"{m.group(1)}--hivemind-agents"
    return name


def aggregate_instances(data, expand_worktrees=False):
    """Aggregate --instances output (projects -> days)."""
    projects = data["projects"]
    daily = defaultdict(lambda: {"output": 0, "cache_read": 0, "cache_write": 0, "total": 0, "cost": 0.0})
    project_totals = defaultdict(lambda: {"output": 0, "cache_read": 0, "cache_write": 0, "total": 0, "cost": 0.0})

    for proj, days in projects.items():
        name = normalize_project_name(proj, expand_worktrees)
        for d in days:
            date = d["date"]
            daily[date]["output"] += d["outputTokens"]
            daily[date]["cache_read"] += d["cacheReadTokens"]
            daily[date]["cache_write"] += d["cacheCreationTokens"]
            daily[date]["total"] += d["totalTokens"]
            daily[date]["cost"] += d["totalCost"]
            project_totals[name]["output"] += d["outputTokens"]
            project_totals[name]["cache_read"] += d["cacheReadTokens"]
            project_totals[name]["cache_write"] += d["cacheCreationTokens"]
            project_totals[name]["total"] += d["totalTokens"]
            project_totals[name]["cost"] += d["totalCost"]

    return daily, project_totals


def aggregate_flat(data, key):
    """Aggregate flat output (daily/weekly/sessions array)."""
    daily = {}
    for d in data[key]:
        label = d.get("date", d.get("week", d.get("sessionId", "unknown")))
        daily[label] = {
            "output": d["outputTokens"],
            "cache_read": d["cacheReadTokens"],
            "cache_write": d["cacheCreationTokens"],
            "total": d["totalTokens"],
            "cost": d["totalCost"],
        }
    return daily, None


def print_table(title, rows, label_header="Date"):
    """Print a formatted summary table."""
    print(f"\n{title}")
    print(f"{'─' * 82}")
    print(f"  {label_header:<32} {'Output':>8} {'Cache Read':>10} {'Cache Write':>11} {'Total':>8} {'Cost':>10}")
    print(f"  {'─' * 32} {'─' * 8} {'─' * 10} {'─' * 11} {'─' * 8} {'─' * 10}")

    total_cost = 0
    for label, d in rows:
        total_cost += d["cost"]
        print(
            f"  {label:<32} {fmt_tokens(d['output']):>8} "
            f"{fmt_tokens(d['cache_read']):>10} {fmt_tokens(d['cache_write']):>11} "
            f"{fmt_tokens(d['total']):>8} "
            f"${d['cost']:>9.2f}"
        )

    print(f"  {'─' * 32} {'─' * 8} {'─' * 10} {'─' * 11} {'─' * 8} {'─' * 10}")
    print(f"  {'TOTAL':<32} {'':>8} {'':>10} {'':>11} {'':>8} ${total_cost:>9.2f}")


def main():
    parser = argparse.ArgumentParser(description="Aggregate ccusage JSON output")
    parser.add_argument("file", help="Path to ccusage JSON output")
    parser.add_argument("--expand-worktrees", action="store_true",
                        help="Show individual worktree sessions instead of aggregating into --hivemind-agents")
    args = parser.parse_args()

    with open(args.file) as f:
        data = json.load(f)

    if "projects" in data:
        daily, project_totals = aggregate_instances(data, args.expand_worktrees)

        # Daily summary
        sorted_daily = sorted(daily.items())
        print_table("DAILY SUMMARY", sorted_daily)

        # Project summary (top 15 by cost)
        sorted_projects = sorted(project_totals.items(), key=lambda x: -x[1]["cost"])[:15]
        print_table("TOP PROJECTS BY COST", sorted_projects, label_header="Project")

        if len(project_totals) > 15:
            rest_cost = sum(d["cost"] for _, d in sorted(project_totals.items(), key=lambda x: -x[1]["cost"])[15:])
            print(f"  ... and {len(project_totals) - 15} more projects (${rest_cost:.2f} combined)")
    else:
        # Flat format (daily, weekly, sessions, blocks)
        key = next((k for k in ("daily", "weekly", "sessions", "blocks") if k in data), None)
        if not key:
            print("Unrecognized ccusage output format", file=sys.stderr)
            sys.exit(1)

        daily, _ = aggregate_flat(data, key)
        label = key.rstrip("s").capitalize() if key != "daily" else "Date"
        sorted_rows = list(daily.items())
        print_table(f"{key.upper()} SUMMARY", sorted_rows, label_header=label)


if __name__ == "__main__":
    main()
