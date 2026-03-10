---
name: lightbulb
description: >
  Use when the user provides a GitHub issue number OR a topic/idea and wants
  end-to-end autonomous development — planning, implementation, review, and PR
  creation — handled by subagents in an isolated worktree. When given a topic
  instead of an issue number, brainstorms a design first and files it as a
  GitHub issue before proceeding.
---

# Lightbulb

End-to-end autonomous development from a GitHub issue or a topic/idea. When given a topic instead of an issue number, brainstorms a design and files it as a GitHub issue first. Then dispatches subagents for each phase: planning, implementation, review, and fix. All work happens in an isolated git worktree. The orchestrator (you) manages phase transitions, relays user interaction, and handles the PR lifecycle.

**Announce at start:**
- **Issue mode:** "I'm using the lightbulb skill to develop issue #N end-to-end."
- **Topic mode:** "I'm using the lightbulb skill to brainstorm and develop a new idea end-to-end."

## Input

- `issue_number` OR `topic` (one required):
  - `issue_number` — GitHub issue number in the current repo. Triggers **issue mode**.
  - `topic` — free-text idea or feature description. Triggers **topic mode**.
- `max_review_rounds` (optional, default 5) — cap on review-fix loop iterations.

Parse these from the user's message. If the message contains a `#N` reference or bare number referring to a GitHub issue, use issue mode. If it contains a topic/idea description without an issue number, use topic mode. If ambiguous, ask.

## Scope

**All actions must serve the target issue.** The orchestrator and its subagents must only perform actions that are part of the defined flow for the issue they were invoked with. Specifically:

- **Do not** act on observations about other issues, PRs, labels, or repository state that are not directly required by the target issue's flow.
- **Do not** close, comment on, triage, or modify other issues -- even if they appear to be duplicates, related, or stale.
- **Do not** modify files, branches, or PRs that are not part of the current worktree and development flow.
- **Do** stay strictly within the steps defined in the Flow section below. If you notice something outside the target issue that seems worth doing, ignore it -- the user can handle it separately.

If the target issue's body explicitly references another issue as a dependency or prerequisite (e.g., "this depends on #5 being merged first"), you may read that issue for context but must not modify it.

## Flow

```
IF TOPIC MODE:
  0a. Parse input (topic text, optional max rounds)
  0b. BRAINSTORM — dispatch brainstorming subagent with the topic
  0c. Create GitHub issue from brainstorm output (design doc = issue body)
  0d. Set issue_number to the newly created issue, fall through to step 1

BOTH MODES (from here on, issue_number is always set):
  1. Parse/fetch issue from GitHub
  2. Set up worktree — REQUIRED SUB-SKILL: superpowers:using-git-worktrees
  3. PLAN — dispatch planning subagent
  4. IMPLEMENT — dispatch implementation subagent
  5. Create draft PR linked to the issue
  6. REVIEW LOOP (up to N rounds)
  7. Check CI pipelines
  8. Ask user: mark PR ready (default) or merge
```

## Topic Mode: Step 0b — BRAINSTORM Phase

After parsing the input (Step 0a), if topic mode is active, dispatch a brainstorming subagent.

**This step only runs in topic mode** (when the user provides a topic instead of an issue number).

Dispatch a brainstorming subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with this prompt structure:

> You are a brainstorming agent. Your job is to explore a topic and produce a design document.
>
> **Topic:** {TOPIC_TEXT}
>
> Use `superpowers:brainstorming` to explore the codebase, understand the problem space, and design a solution. When brainstorming needs user input (clarifying questions, design choices), return them to me — I will relay to the user and resume you with answers.
>
> **IMPORTANT differences from normal brainstorming:**
> - Do NOT invoke `superpowers:writing-plans` at the end. Your job ends when the design is complete.
> - Do NOT write a design doc to disk. Instead, return the complete design document as your final output.
> - When the design is complete, return a message starting with `DESIGN_COMPLETE:` followed by the full design document text.
>
> When you need user input, return a message starting with `USER_INPUT_NEEDED:` followed by the question.
>
> **Scope:** Stay focused on the topic provided. Do not act on observations about other issues, PRs, or unrelated repository state.

**Relay pattern:** Same as the planning phase — relay `USER_INPUT_NEEDED:` to the user via `AskUserQuestion`, resume subagent with answers.

**When DESIGN_COMPLETE:** Capture the design text and proceed to Step 0c.

## Topic Mode: Step 0c — Create GitHub Issue

**This step only runs in topic mode**, after the brainstorm subagent returns `DESIGN_COMPLETE:`.

1. **Extract a title** from the design document: use the first `# heading` in the design text. If there is no heading, use the first sentence.

2. **Create the issue** using a HEREDOC to safely handle multiline Markdown, quotes, and backticks in the design text:

```
gh issue create --title "<extracted-title>" --body "$(cat <<'EOF'
<full-design-text>
EOF
)"
```

**Note on shell escaping:** The `<<'EOF'` (single-quoted delimiter) prevents any shell expansion inside the body. This is important because the design document will contain backticks, quotes, dollar signs, and other characters that would otherwise be interpreted by the shell.

3. **Capture the issue number** from the command output (gh prints the issue URL, extract the number from it).

4. **Announce:** "Created issue #N: <title>. Proceeding with development."

5. **Set `issue_number`** to the newly created number and **fall through to Step 1** below. From this point forward, the flow is identical to issue mode.

**Error handling:** If `gh issue create` fails (network error, auth issue, etc.), save the design text to `docs/plans/brainstorm-<slug>.md` as a backup before reporting the error to the user. This ensures the brainstorm work is not lost even if issue creation fails.

## Step 1: Fetch Issue

Use `gh issue view <number> --json title,body,labels` or the GitHub MCP tool to fetch the issue. Store the title and body — you'll pass these to subagents.

If the issue doesn't exist or is closed, tell the user and stop.

## Step 2: Set Up Worktree

**REQUIRED SUB-SKILL:** Use `superpowers:using-git-worktrees` to create an isolated workspace.

The worktree branch name should be derived from the issue: `feature/issue-<number>-<slug>` where `<slug>` is a short kebab-case summary of the issue title.

**After worktree setup, store the worktree path and verify ownership:**

The `superpowers:using-git-worktrees` skill outputs the worktree path. Store it in a variable for all subsequent git operations:

```
WORKTREE_PATH="<path returned by using-git-worktrees>"
```

Use `git -C "$WORKTREE_PATH"` for **all** git commands that target the worktree. This avoids `cd <path> && git <command>` chains that trigger Claude Code's bare repository security prompts.

```bash
# Verify the current branch contains this issue's number
CURRENT_BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD)
echo "$CURRENT_BRANCH" | grep -q "issue-<number>" || echo "BRANCH_MISMATCH"
```

If the branch name does not contain `issue-<number>` (where `<number>` is your target issue number), **stop immediately** and report the error to the user. Do not proceed to Step 3. This prevents piggybacking on another agent's worktree when parallel agents are running.

## Step 3: PLAN Phase

Dispatch a planning subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with this prompt structure:

> You are a planning agent. Your job is to design and plan the implementation for a GitHub issue.
>
> **Issue #N: {ISSUE_TITLE}**
>
> {ISSUE_BODY}
>
> Use `superpowers:brainstorming` to explore the codebase, understand the problem, and design a solution. When brainstorming needs user input (clarifying questions, design choices), return them to me — I will relay to the user and resume you with answers.
>
> After brainstorming is complete, use `superpowers:writing-plans` to write a detailed implementation plan to `docs/plans/YYYY-MM-DD-<topic>.md`.
>
> Do NOT proceed to implementation. Do NOT invoke finishing-a-development-branch. Your job ends when the plan file is written.
>
> When you need user input, return a message starting with `USER_INPUT_NEEDED:` followed by the question.
>
> When the plan is complete, return a message starting with `PLAN_COMPLETE:` followed by the plan file path.
>
> **Scope:** Stay focused on issue #{N}. Do not act on observations about other issues, PRs, or unrelated repository state.

**Relay pattern:** When the planning subagent returns `USER_INPUT_NEEDED:`, use `AskUserQuestion` to relay the question to the user, then resume the subagent (Agent tool with `resume` parameter) with the user's answer.

**When PLAN_COMPLETE:** Read the plan file, commit it, and proceed to Step 4.

```
git -C "$WORKTREE_PATH" add docs/plans/*.md
git -C "$WORKTREE_PATH" commit -m "docs: add implementation plan for issue #N"
```

## Step 4: IMPLEMENT Phase

Read the plan file to get the full plan text.

Dispatch an implementation subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with this prompt structure:

> You are an implementation agent. Implement the following plan using `superpowers:subagent-driven-development`.
>
> **Plan:**
>
> {FULL_PLAN_TEXT}
>
> Follow the plan task by task. SDD will handle per-task reviews (spec + quality).
>
> **IMPORTANT:** Do NOT invoke `superpowers:finishing-a-development-branch` when done. The orchestrator handles the PR lifecycle. When all tasks are complete, just report back.
>
> When you need clarification, return a message starting with `USER_INPUT_NEEDED:` followed by the question.
>
> When implementation is complete, return a message starting with `IMPLEMENTATION_COMPLETE:` followed by a summary of what was implemented.
>
> **Scope:** Implement only what the plan specifies. Do not act on observations about other issues, PRs, or unrelated repository state.

**Relay pattern:** Same as planning — relay `USER_INPUT_NEEDED:` to the user, resume with answers.

**When IMPLEMENTATION_COMPLETE:** Proceed to Step 5.

## Step 5: Create Draft PR

Push the worktree branch and create a draft PR:

```
git -C "$WORKTREE_PATH" push -u origin <branch-name>
gh pr create --draft --title "<issue-title>" --body "$(cat <<'EOF'
## Summary

<2-3 bullets summarizing the implementation>

Closes #<issue-number>

---

Autonomously developed with the lightbulb skill.

— Claude
EOF
)"
```

Store the PR number for posting review comments.

## Step 6: Review Loop

Track the current round number (starting at 1) and the max rounds (default 5).

**For each round:**

1. Get the full diff against the base branch (detect it dynamically — do not hardcode `main`):

```
BASE=$(git -C "$WORKTREE_PATH" symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
git -C "$WORKTREE_PATH" diff $BASE...HEAD
```

2. Read the plan file for spec context.

3. Dispatch a reviewer subagent (Agent tool, `subagent_type: "superpowers:code-reviewer"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with:

> You are a code reviewer. Review the following implementation for BOTH spec compliance and code quality.
>
> **Plan (spec):**
>
> {FULL_PLAN_TEXT}
>
> **Diff:**
>
> {FULL_DIFF}
>
> Review for:
> - **Spec compliance:** Does the implementation match the plan? Anything missing or extra?
> - **Code quality:** Is the code well-structured, tested, maintainable? Any bugs, security issues, performance problems?
>
> Categorize each issue as:
> - **Critical:** Must fix — bugs, security issues, missing requirements
> - **Important:** Should fix — poor patterns, missing tests, unclear code
> - **Cosmetic:** Nice to have — style, naming, minor improvements
>
> **Status rule — follow strictly:**
> - If Critical > 0 OR Important > 0 → Status MUST be `NEEDS_FIXES`
> - If Critical = 0 AND Important = 0 → Status MUST be `APPROVED`
> - Never approve when Important or Critical issues exist, regardless of their severity relative to the overall quality
>
> Return your review in this format:
>
> ```
> REVIEW_RESULT:
> Status: APPROVED | NEEDS_FIXES
> Critical: <count>
> Important: <count>
> Cosmetic: <count>
>
> ## Issues
> ### Critical
> - ...
> ### Important
> - ...
> ### Cosmetic
> - ...
>
> ## Strengths
> - ...
> ```
>
> **Scope:** Review only the diff provided. Do not comment on or act on other issues, PRs, or unrelated repository state.

4. Post the review as a PR comment (signed "— Claude"):

```
gh pr comment <pr-number> --body "$(cat <<'EOF'
<review-content>

— Claude
EOF
)"
```

5. **Validate the reviewer's status.** Parse the `Critical:` and `Important:` counts from the `REVIEW_RESULT` block. If either count is greater than 0 but the reviewer returned `Status: APPROVED`, override the status to `NEEDS_FIXES` and log: "Overriding reviewer status: found N critical and M important issues but reviewer returned APPROVED."

   This is a safety net — the reviewer prompt's status rule should already produce the correct status, but the orchestrator enforces the rule independently.

6. **If Status is NEEDS_FIXES** (critical or important issues):

   Dispatch a fixer subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with:

   > You are a code fixer. Fix the following review issues:
   >
   > {REVIEW_ISSUES — critical and important only}
   >
   > Fix each issue, run tests to verify, and commit your changes.
   >
   > When done, return `FIXES_COMPLETE:` followed by a summary.
   >
   > **Scope:** Fix only the listed issues. Do not act on observations about other issues, PRs, or unrelated repository state.

   After fixes, push the changes (`git -C "$WORKTREE_PATH" push`) so the PR stays current, increment round counter, and loop back to step 1.

7. **If Status is APPROVED** (only cosmetic issues remain):

   If cosmetic issues exist and rounds remain, ask the user:

   > The reviewer approved with N cosmetic suggestions. Would you like to fix those too?
   > 1. Yes, fix cosmetics (Recommended)
   > 2. No, move on

   If yes: dispatch fixer with cosmetic issues, increment round, re-review.
   If no: exit loop.

8. **If max rounds reached:** Post remaining issues as a PR comment and exit loop.

## Step 7: CI Check

After the review loop converges:

```
gh pr checks <pr-number> --watch
```

If checks fail, dispatch a fixer subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`, `permissionMode: "acceptEdits"`) with the failure output:

> CI pipeline failed. Diagnose and fix:
>
> {FAILURE_OUTPUT}
>
> Fix the issue, run tests locally to verify, and commit.
>
> **Scope:** Fix only the CI failure. Do not act on observations about other issues, PRs, or unrelated repository state.

Re-check after fixes. If CI still fails after 2 fix attempts, report to user and stop.

## Step 8: Completion

All review rounds passed and CI is green. Ask the user:

> Development complete for issue #N.
> 1. Mark PR ready for review (Recommended)
> 2. Mark PR ready and merge directly

**Option 1:** Run `gh pr ready <pr-number>` — marks the draft PR as ready for human review.

**Option 2:** Run `gh pr ready <pr-number>` then `gh pr merge <pr-number> --squash` — marks the PR ready and immediately merges it. Do NOT run merge a second time; the single `gh pr merge` command here is the only merge.

## Error Handling

If any subagent fails or returns an unexpected result:

1. Report the failure to the user with context (which phase, what happened).
2. Ask: Retry / Skip this phase / Abort entirely.
3. Never silently continue past a failed phase.

If a subagent needs user input but doesn't use the `USER_INPUT_NEEDED:` protocol, check its output for questions and relay them manually.

## Red Flags

**Never:**
- Write code yourself — always dispatch a subagent
- Skip the review loop — even if implementation "looks good"
- Continue past a failed phase without user acknowledgment
- Create a PR before implementation is complete
- Dispatch subagents in parallel — phases are sequential
- Post review comments without signing "— Claude"
- Merge without explicit user consent
- Run more review rounds than the configured max
- Accept an APPROVED review that has Critical or Important issues — always override to NEEDS_FIXES
- Act on observations about other issues, PRs, or repository state that are outside the target issue's flow -- even if they seem helpful (e.g., closing duplicates, triaging, commenting on other PRs)
- Run commands not defined in the skill flow (e.g., `gh issue close`, `gh issue edit`, `gh pr close` are never part of the lightbulb flow)
- Work in a worktree or commit to a branch that belongs to a different issue -- if your worktree is inaccessible or the branch name doesn't match your issue number, report the error and stop

**Always:**
- Relay brainstorming questions to the user — don't answer them yourself
- Commit after each phase (plan, implementation fixes, review fixes, CI fixes)
- Use simple `git commit -m "message"` — never use HEREDOC/cat patterns for commit messages (they trigger unnecessary confirmation prompts)
- Post every review on the PR as a comment
- Check CI after the review loop converges
- Ask the user before merging or marking ready
- In topic mode, create the GitHub issue before proceeding to the normal flow — never skip issue creation
- Ensure all orchestrator Bash commands have matching entries in the user's `permissions.allow` — see README for the setup script and manual list
- Verify after worktree setup that the current branch name contains your issue number -- never proceed if it doesn't match
- Use `git -C "$WORKTREE_PATH"` for all orchestrator git commands targeting the worktree -- never use `cd <path> && git <command>` chains, as they trigger Claude Code's bare repository security prompts

## Integration

**Skills called (via subagents):**
- `superpowers:using-git-worktrees` — worktree setup (orchestrator invokes directly)
- `superpowers:brainstorming` — topic-to-issue brainstorm (topic mode, brainstorming subagent) AND design exploration (planning subagent)
- `superpowers:writing-plans` — plan creation (planning subagent)
- `superpowers:subagent-driven-development` — implementation (implementer subagent)

**Skills NOT called:**
- `superpowers:finishing-a-development-branch` — orchestrator handles PR lifecycle directly
- `superpowers:executing-plans` — SDD used instead
