# Fold Issue Creation into Brainstorm Phase -- Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend the lightbulb skill's SKILL.md to accept a topic/idea as an alternative to an issue number, brainstorm a design, file it as a GitHub issue, and then continue with the existing end-to-end development flow.

**Architecture:** Purely additive changes to `skills/lightbulb/SKILL.md`. A new conditional prefix (steps 0a-0d) handles topic-mode input: dispatches a brainstorming subagent, creates a GitHub issue from the design output, then hands off to the existing flow (steps 1-8) unchanged. The existing issue-mode path is not modified.

**Tech Stack:** Claude Code skill (YAML frontmatter + Markdown). No code dependencies.

---

## Task 1: Update frontmatter and overview to reflect dual entry points

**Files:**
- Modify: `skills/lightbulb/SKILL.md:1-13`

### Step 1: Update the frontmatter description

Replace the current frontmatter `description` (lines 3-6):

```yaml
description: >
  Use when the user provides a GitHub issue number and wants end-to-end
  autonomous development — planning, implementation, review, and PR creation —
  handled by subagents in an isolated worktree.
```

With:

```yaml
description: >
  Use when the user provides a GitHub issue number OR a topic/idea and wants
  end-to-end autonomous development — planning, implementation, review, and PR
  creation — handled by subagents in an isolated worktree. When given a topic
  instead of an issue number, brainstorms a design first and files it as a
  GitHub issue before proceeding.
```

### Step 2: Update the overview paragraph

Replace the current overview paragraph (line 11):

```
End-to-end autonomous development from a GitHub issue. Dispatches subagents for each phase: planning, implementation, review, and fix. All work happens in an isolated git worktree. The orchestrator (you) manages phase transitions, relays user interaction, and handles the PR lifecycle.
```

With:

```
End-to-end autonomous development from a GitHub issue or a topic/idea. When given a topic instead of an issue number, brainstorms a design and files it as a GitHub issue first. Then dispatches subagents for each phase: planning, implementation, review, and fix. All work happens in an isolated git worktree. The orchestrator (you) manages phase transitions, relays user interaction, and handles the PR lifecycle.
```

### Step 3: Update the announcement line

Replace the current announcement (line 13):

```
**Announce at start:** "I'm using the lightbulb skill to develop issue #N end-to-end."
```

With:

```
**Announce at start:**
- **Issue mode:** "I'm using the lightbulb skill to develop issue #N end-to-end."
- **Topic mode:** "I'm using the lightbulb skill to brainstorm and develop a new idea end-to-end."
```

### Step 4: Verify the top of the file reads correctly

Run: `head -18 skills/lightbulb/SKILL.md`

Expected: Updated frontmatter with dual-entry description, updated overview paragraph mentioning topic mode, and both announcement variants.

### Step 5: Commit

```
feat(lightbulb): update frontmatter and overview for topic mode
```

---

## Task 2: Update Input section and Flow diagram

**Files:**
- Modify: `skills/lightbulb/SKILL.md:15-34` (approximate, after Task 1 line shifts)

### Step 1: Replace the Input section

Replace the current `## Input` section:

```markdown
## Input

- `issue_number` (required) — GitHub issue number in the current repo.
- `max_review_rounds` (optional, default 5) — cap on review-fix loop iterations.

Parse these from the user's message. If the issue number is ambiguous, ask.
```

With:

```markdown
## Input

- `issue_number` OR `topic` (one required):
  - `issue_number` — GitHub issue number in the current repo. Triggers **issue mode**.
  - `topic` — free-text idea or feature description. Triggers **topic mode**.
- `max_review_rounds` (optional, default 5) — cap on review-fix loop iterations.

Parse these from the user's message. If the message contains a `#N` reference or bare number referring to a GitHub issue, use issue mode. If it contains a topic/idea description without an issue number, use topic mode. If ambiguous, ask.
```

### Step 2: Replace the Flow diagram

Replace the current `## Flow` section:

````markdown
## Flow

```
1. Parse input (issue number, optional max rounds)
2. Fetch issue from GitHub
3. Set up worktree — REQUIRED SUB-SKILL: superpowers:using-git-worktrees
4. PLAN — dispatch planning subagent
5. IMPLEMENT — dispatch implementation subagent
6. Create draft PR linked to the issue
7. REVIEW LOOP (up to N rounds)
8. Check CI pipelines
9. Ask user: mark PR ready (default) or merge
```
````

With:

````markdown
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
````

### Step 3: Verify the Input and Flow sections

Run: `sed -n '/^## Input/,/^## Step/p' skills/lightbulb/SKILL.md | head -30`

Expected: Updated Input section with `issue_number OR topic`, followed by updated Flow diagram with topic mode prefix.

### Step 4: Commit

```
feat(lightbulb): update input and flow for dual entry points
```

---

## Task 3: Add Step 0b (BRAINSTORM phase) and Step 0c (Create GitHub Issue)

**Files:**
- Modify: `skills/lightbulb/SKILL.md` — insert new sections before `## Step 1: Fetch Issue`

### Step 1: Insert the new topic-mode sections

Insert the following immediately before the existing `## Step 1: Fetch Issue` line:

```markdown
## Topic Mode: Step 0b — BRAINSTORM Phase

**This step only runs in topic mode** (when the user provides a topic instead of an issue number).

Dispatch a brainstorming subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`) with this prompt structure:

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

**Relay pattern:** Same as the planning phase — relay `USER_INPUT_NEEDED:` to the user via `AskUserQuestion`, resume subagent with answers.

**When DESIGN_COMPLETE:** Capture the design text and proceed to Step 0c.

## Topic Mode: Step 0c — Create GitHub Issue

**This step only runs in topic mode**, after the brainstorm subagent returns `DESIGN_COMPLETE:`.

1. **Extract a title** from the design document: use the first `# heading` in the design text. If there is no heading, use the first sentence.

2. **Create the issue:**

```
gh issue create --title "<extracted-title>" --body "<full-design-text>"
```

3. **Capture the issue number** from the command output (gh prints the issue URL, extract the number from it).

4. **Announce:** "Created issue #N: <title>. Proceeding with development."

5. **Set `issue_number`** to the newly created number and **fall through to Step 1** below. From this point forward, the flow is identical to issue mode.

```

### Step 2: Verify the new sections appear before Step 1

Run: `grep -n "^## " skills/lightbulb/SKILL.md`

Expected output should show (in order): `## Topic Mode: Step 0b`, `## Topic Mode: Step 0c`, `## Step 1: Fetch Issue`, followed by the rest of the existing steps.

### Step 3: Commit

```
feat(lightbulb): add brainstorm and issue creation steps for topic mode
```

---

## Task 4: Update Integration and Red Flags sections

**Files:**
- Modify: `skills/lightbulb/SKILL.md` — update the Integration and Red Flags sections at the end of the file

### Step 1: Update the Integration section

Replace the current `## Integration` section:

```markdown
## Integration

**Skills called (via subagents):**
- `superpowers:using-git-worktrees` — worktree setup (orchestrator invokes directly)
- `superpowers:brainstorming` — design exploration (planning subagent)
- `superpowers:writing-plans` — plan creation (planning subagent)
- `superpowers:subagent-driven-development` — implementation (implementer subagent)

**Skills NOT called:**
- `superpowers:finishing-a-development-branch` — orchestrator handles PR lifecycle directly
- `superpowers:executing-plans` — SDD used instead
```

With:

```markdown
## Integration

**Skills called (via subagents):**
- `superpowers:using-git-worktrees` — worktree setup (orchestrator invokes directly)
- `superpowers:brainstorming` — topic-to-issue brainstorm (topic mode, brainstorming subagent) AND design exploration (planning subagent)
- `superpowers:writing-plans` — plan creation (planning subagent)
- `superpowers:subagent-driven-development` — implementation (implementer subagent)

**Skills NOT called:**
- `superpowers:finishing-a-development-branch` — orchestrator handles PR lifecycle directly
- `superpowers:executing-plans` — SDD used instead
```

### Step 2: Add a new item to the Red Flags "Always" list

In the `## Red Flags` section, find the `**Always:**` list and add this item after the last existing bullet:

```markdown
- In topic mode, create the GitHub issue before proceeding to the normal flow — never skip issue creation
```

### Step 3: Verify the updated sections

Run: `tail -25 skills/lightbulb/SKILL.md`

Expected: Updated Integration section with the brainstorming bullet mentioning both topic mode and planning subagent usage, and the Red Flags "Always" list with the new bullet about topic mode issue creation.

### Step 4: Commit

```
feat(lightbulb): update integration and red flags for topic mode
```

---

## Task 5: End-to-end verification

**Files:**
- Read: `skills/lightbulb/SKILL.md` (full file)

### Step 1: Read the complete SKILL.md end-to-end

Read the entire file and verify:

1. Frontmatter `description` mentions both issue number and topic/idea.
2. Overview paragraph mentions topic mode.
3. Two announcement variants (issue mode and topic mode).
4. Input section accepts `issue_number OR topic`.
5. Flow diagram shows the topic mode prefix (steps 0a-0d) followed by the shared steps (1-8).
6. `## Topic Mode: Step 0b` section exists with the brainstorming subagent prompt.
7. `## Topic Mode: Step 0c` section exists with `gh issue create` and title extraction.
8. Steps 1-8 are unchanged from the original.
9. Integration section mentions brainstorming for both topic mode and planning subagent.
10. Red Flags "Always" list includes the topic mode issue creation item.

### Step 2: Verify section ordering

Run: `grep -n "^## " skills/lightbulb/SKILL.md`

Expected section order:
```
## Input
## Flow
## Topic Mode: Step 0b — BRAINSTORM Phase
## Topic Mode: Step 0c — Create GitHub Issue
## Step 1: Fetch Issue
## Step 2: Set Up Worktree
## Step 3: PLAN Phase
## Step 4: IMPLEMENT Phase
## Step 5: Create Draft PR
## Step 6: Review Loop
## Step 7: CI Check
## Step 8: Completion
## Error Handling
## Red Flags
## Integration
```

### Step 3: Verify file is well-formed

Run: `wc -l skills/lightbulb/SKILL.md`

Expected: approximately 330-360 lines (original was 286, adding ~50-70 lines of new content).

### Step 4: Commit (if any fixes were needed)

Only commit if corrections were made during verification. Commit message:

```
fix(lightbulb): address verification findings in topic mode additions
```

---

## Verification

After all tasks, the complete SKILL.md should support two modes:

1. **Issue mode** (existing, unchanged): `lightbulb #42` or `lightbulb issue 42` -- fetches the issue and proceeds through plan/implement/review/PR.

2. **Topic mode** (new): `lightbulb add dark mode support` -- brainstorms the idea, files a GitHub issue with the full design as the body, then hands off to the existing flow with the new issue number.

The existing flow (steps 1-8) is completely untouched. The only additions are:
- Updated frontmatter, overview, input, and flow sections to describe both modes
- Two new sections (Step 0b, Step 0c) inserted before Step 1
- Updated Integration and Red Flags sections
