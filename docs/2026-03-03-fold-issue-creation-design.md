# Fold Issue Creation into the Brainstorm Phase -- Design Document

**Goal:** Extend the lightbulb skill to accept a topic/idea as input (in addition to an issue number), brainstorm a design, file it as a GitHub issue, and then continue with the normal end-to-end development flow.

---

## Entry Points

The skill gains a second entry point. The orchestrator detects which mode based on input parsing:

- **Issue mode (existing):** User provides `issue_number` -- current flow, unchanged.
- **Topic mode (new):** User provides a `topic` (free-text idea/description) instead of an issue number -- triggers the brainstorm-to-issue flow first, then hands off to the existing flow.

---

## Input Changes

The `## Input` section of SKILL.md changes from:

```
- issue_number (required)
- max_review_rounds (optional, default 5)
```

To:

```
- issue_number OR topic (one required)
- max_review_rounds (optional, default 5)
```

If the user's message contains a GitHub issue number, use issue mode. If it contains a topic/idea description without an issue number, use topic mode. If ambiguous, ask.

---

## New Flow (Topic Mode)

```
0a. Parse input (topic text, optional max rounds)
0b. BRAINSTORM -- dispatch brainstorming subagent with the topic
0c. Create GitHub issue from brainstorm output (design doc = issue body)
0d. Hand off to existing flow at Step 1 (Fetch Issue) with the new issue number
```

After step 0d, the flow is identical to the existing issue mode -- fetch issue, worktree, plan (brainstorms again), implement, review, PR. The existing steps 1-8 are completely unchanged.

---

## Step 0b: BRAINSTORM Phase (New)

The orchestrator dispatches a brainstorming subagent (Agent tool, `subagent_type: "general-purpose"`, `model: "opus"`) with this prompt:

> You are a brainstorming agent. Your job is to explore a topic and produce a design document.
>
> **Topic:** {TOPIC_TEXT}
>
> Use `superpowers:brainstorming` to explore the codebase, understand the problem space, and design a solution. When brainstorming needs user input (clarifying questions, design choices), return them to me -- I will relay to the user and resume you with answers.
>
> **IMPORTANT differences from normal brainstorming:**
> - Do NOT invoke `superpowers:writing-plans` at the end. Your job ends when the design is complete.
> - Do NOT write a design doc to disk. Instead, return the complete design document as your final output.
> - When the design is complete, return a message starting with `DESIGN_COMPLETE:` followed by the full design document text.
>
> When you need user input, return a message starting with `USER_INPUT_NEEDED:` followed by the question.

**Relay pattern:** Same as existing planning phase -- relay `USER_INPUT_NEEDED:` to the user via `AskUserQuestion`, resume subagent with answers.

**When DESIGN_COMPLETE:** The orchestrator captures the design text and proceeds to step 0c.

---

## Step 0c: Create GitHub Issue (New)

The orchestrator:

1. Extracts a title from the design document (first `# heading`, or first sentence if no heading).
2. Creates the issue:
   ```
   gh issue create --title "<extracted-title>" --body "<full-design-text>"
   ```
3. Captures the new issue number from the command output.
4. Announces: "Created issue #N: <title>. Proceeding with development."

---

## Step 0d: Hand Off to Existing Flow

The orchestrator sets `issue_number` to the newly created issue number and proceeds to Step 1 (Fetch Issue) -- the existing flow takes over entirely. The planning subagent will brainstorm again (which is fine -- it explores the codebase with the issue as context), then writes the implementation plan, and everything continues as before.

---

## Announcement Change

The announcement at start changes based on mode:

- **Issue mode:** "I'm using the lightbulb skill to develop issue #N end-to-end." (unchanged)
- **Topic mode:** "I'm using the lightbulb skill to brainstorm and develop a new idea end-to-end."

---

## SKILL.md Structure Changes

The modifications are purely additive:

1. **Frontmatter `description`:** Updated to mention both entry points.
2. **`## Input`:** Updated to accept either `issue_number` or `topic`.
3. **`## Flow`:** Gains a conditional prefix (steps 0a-0d) before the existing step 1.
4. **New sections:** `## Step 0b: BRAINSTORM Phase` and `## Step 0c: Create GitHub Issue` added before the existing Step 1.
5. **Existing sections (Steps 1-8):** Completely unchanged.
6. **`## Integration`:** Updated to note that brainstorming is also used directly by the orchestrator (not just via the planning subagent).

---

## What Does NOT Change

- Steps 1-8 (the entire existing flow)
- The planning subagent prompt and behavior
- The implementation, review, CI, and completion phases
- Error handling patterns
- Red flags section (though we add one new "Always" item about creating issues from brainstorms)
