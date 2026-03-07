# Implementation Plan: Document Topic Mode Usage in README

## Issue

#18 — README: document topic mode usage

## Problem

The README's Usage section only shows issue mode (`/lightbulb 42`). Topic mode — where the user provides an idea/topic instead of an issue number — is not documented. A new user wouldn't know this capability exists without reading SKILL.md.

## Scope

README.md only. No functionality changes.

## Tasks

### Task 1: Add topic mode usage example to README Usage section

**File:** `README.md`

**Change:** In the `## Usage` section, after the existing issue mode examples, add a new subsection or paragraph showing topic mode usage with an example like:

```
/lightbulb add a changelog that auto-generates from PR titles
```

Include a brief explanation that topic mode brainstorms a design and files it as a GitHub issue before proceeding with development.

**Acceptance criteria:**
- Topic mode usage example is clearly documented
- Both issue mode and topic mode are presented as parallel options
- The example matches the style of existing usage examples
- No functional changes to any code files

### Task 2: Update the lightbulb description to mention topic mode

**File:** `README.md`

**Change:** Update the lightbulb skill description (line 9) to mention that it also accepts topics/ideas, not just issue numbers. This aligns with the SKILL.md description which already mentions both modes.

**Acceptance criteria:**
- The description mentions both issue mode and topic mode
- Consistent with SKILL.md's description
