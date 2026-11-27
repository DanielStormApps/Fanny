---
name: /review-plan
description: review plan against codebase
argument-hint: "[plan name or keyword]"
disable-model-invocation: false
---

# Plan Review

## Overview

Coordinate a team of parallel reviewer agents to verify a plan file against the actual codebase. Do not edit any code within the project. Output should be replies only. Use ultrathink mode.

## Workflow

### Step 1: Identify the Plan

Determine which plan to review based on `$ARGUMENTS`:

- If a **plan name or keyword** is provided, find the matching `.md` file in the `plans/` directory.
- If **no argument** is provided, list available plans in `plans/` and ask the user which one to review. If `plans/` does not exist yet, say there are no plans and stop.
- Read the full plan file before spawning agents.

### Step 2: Gather Context

Before spawning reviewers, collect key information:

- Read the entire plan file to understand its structure, phases, and claims.
- Note which existing files the plan references (paths, line numbers, code snippets).
- Note which new files the plan proposes to create.
- Note any dependencies the plan lists.

### Step 3: Spawn Reviewer Agents

Spawn three reviewer agents in parallel using the Agent tool. Give each a descriptive name and set `subagent_type` to `Explore` and `model` to `sonnet` (per `.claude/rules/subagent-models.md`).

Pass each agent:
- The plan's claims relevant to their scope (file paths, line numbers, code excerpts, etc.)
- Clear instructions on what to verify and what to report back.
- Instruction to assume nothing and go look at the actual code.

### Step 4: Review Scopes

The three agents have complementary verification scopes:

**Agent 1 - Current State & Code Accuracy:**
- Verify every line number reference in the plan against the actual file
- Verify every code snippet/excerpt quoted in the plan matches the actual code
- Verify enum cases, property names, method signatures, and parameter lists
- Verify claimed file paths exist at the stated locations
- Verify struct/class definitions, protocols, and conformances
- Check that "add after line X" instructions point to the correct anchor code
- Report exact actual line numbers where they differ from the plan

**Agent 2 - Dependencies, Structure & Completion Status:**
- Verify every dependency listed in the plan exists (base classes, protocols, SPM packages, utilities)
- Verify Xcode project structure claims (group IDs, group contents, build phases)
- Check if any of the new files the plan proposes to create already exist
- Check if any of the modifications the plan describes have already been applied to existing files
- Verify claims about automatic behavior (e.g., "no changes needed to X because Y")
- Check the plan's proposed code for compile errors (wrong imports, missing types, type mismatches)
- Verify the plan's proposed code follows CLAUDE.md code style rules

**Agent 3 - Logic & Runtime Correctness:**
- Review the plan's proposed code for runtime correctness - would it actually work as intended?
- Verify that data flows are complete: state saved → delegate broadcast → UI updates in all affected screens
- Verify delegate/callback chains are wired end-to-end (delegates set, protocols conformed to, methods implemented)
- Check for edge cases: nil values, empty collections, missing resources, invalid input
- Verify that UI update flows cover all paths (e.g., a settings change while the menu is open, sleep and wake, quitting while the widget still shows the last snapshot)
- Check that proposed APIs are used correctly (e.g., `DelegateMulticast` listeners, WidgetKit timeline reloads, App Intents parameters)
- Look for ordering issues (e.g., must X happen before Y?)
- Verify the plan's architectural approach is sound for the codebase's patterns
- Check that proposed code handles failure cases appropriately (missing resources, decode failures, etc.)
- Read the actual codebase patterns the plan claims to follow and confirm the proposed code matches them

All agents should:
- Read the actual source files, not trust the plan's excerpts
- Report findings with exact file paths and line numbers
- Categorize each finding by severity
- Return findings back to the coordinator

### Step 5: Verify Agent Findings

You are the orchestrator. Do not blindly trust agent outputs - verify them before including them in the report.

For each finding an agent reports:
- **Spot-check claims**: If an agent says "line X is actually Y", read the file yourself and confirm. Agents can misread or miscount lines.
- **Dismiss false positives**: If an agent flags something that is actually correct in the plan, drop it.
- **Catch missed issues**: After reviewing agent outputs, consider whether anything obvious was missed given what you read during Step 2. If so, investigate it yourself.
- **Resolve conflicts**: If two agents report contradictory findings about the same thing, read the code and determine which is correct.

Only findings you have confirmed as accurate should proceed to the report.

### Step 6: Consolidate Reviews

After verifying agent findings, consolidate them:

- **Deduplicate**: Merge overlapping findings into single items.
- **Categorize**: Assign each finding to the appropriate severity level.
- **Add context**: Every finding must reference the specific file(s) and, where possible, the plan section it relates to.

### Step 7: Update Completion Status

If any phases or checklist items in the plan can be confirmed as 100% complete based on the codebase review, update the plan file to mark them as done (change `- [ ]` to `- [x]`). Only mark items complete when the code fully matches what the plan describes - partial work does not count.

### Step 8: Auto-Fix Inaccuracies and Style Issues

Before presenting the report, automatically fix all **Inaccuracy** and **Style** findings directly in the plan file using the Edit tool. Run these edits after Step 7 completion checkboxes are finalized so line references are stable. These are low-risk corrections that do not require user review:

- **Inaccuracies**: Update wrong line numbers, off-by-one references, and trivial discrepancies to match the actual codebase.
- **Style**: Fix code snippets in the plan that violate CLAUDE.md code style rules (wrong imports, formatting, naming conventions, etc.).

After fixing, list what was auto-fixed in the report under a dedicated section so the user has visibility, but do not ask for approval - just fix them.

### Step 9: Present the Report

Deliver the consolidated review using the output format below.

### Step 10: Present Actionable Numbered List

After the full report, present a **single flat numbered list** of **Must Fix**, **Should Fix**, and **Logic** findings with the category as a prefix tag. Inaccuracies and Style issues are excluded because they were already auto-fixed in Step 8. This lets the user reply with numbers to indicate which items to fix.

Format:
```
1. **[Must Fix]** Short title - `Phase 3` or `plan line 205` - one-line description
2. **[Should Fix]** Short title - `Phase 1 / SensorMonitor` - one-line description
3. **[Logic]** Short title - `Phase 4 / GeneralSettingsViewController` - one-line description
...
```

Tell the user to reply with the numbers they want fixed in the plan.

## Output Format

Present the final review as follows:

```markdown
# Plan Review: [plan file name]

**Plan:** `plans/<filename>.md`
**Status:** [plan's stated status]
**Phases:** [count]

---

## Completion Status

> Phases or checklist items confirmed as already done in the codebase.

[List completed items, or "No work has been started on any phase."]

## Must Fix
> Issues that would cause compile errors, runtime crashes, or incorrect behavior if the plan were implemented as written.

1. **[Short title]** - `path/to/file.swift` or plan section
   [Description of the issue and what needs to change.]

2. ...

## Should Fix
> Important inaccuracies: wrong line numbers that could cause misplaced code, incorrect code excerpts, missing steps.

1. **[Short title]** - `path/to/file.swift:L42` or plan section
   [Description and the correct information.]

2. ...

## Logic Issues
> Runtime correctness problems: code that would compile but behave incorrectly, incomplete data flows, unhandled edge cases, incorrect API usage.

1. **[Short title]** - `Phase X` or plan section
   [Description of the logic issue and suggested fix.]

2. ...

## Auto-Fixed
> Inaccuracies and style issues that were automatically corrected in the plan file. Listed here for visibility.

- **[Short title]** - [what was changed]
- ...

---

**Summary:** X must-fix, Y should-fix, Z logic issues remain. N inaccuracies and M style issues were auto-fixed.
```

If a category has no findings, include it with "None found." to make it explicit.

## Principles

- **Verify everything.** Assume nothing in the plan is correct until confirmed by reading the actual code.
- **Be precise.** Report actual line numbers and actual code when they differ from the plan.
- **Check for completion.** The user may have partially implemented the plan already. Confirm what is done.
- **Do not edit project code.** This is a review only. The plan file itself may be updated (completion checkboxes, auto-fixed inaccuracies, and style corrections).
- **Do not build.** Per CLAUDE.md, do not attempt to compile or build the project. Verify correctness by reading and analyzing the code directly.
- **Be specific.** Every finding must include a file path or plan section reference. Vague findings are not useful.
- **Check proposed code.** Review the plan's code snippets for compile errors, wrong imports, type mismatches, and style violations as if they were a PR diff.
- **Check logic.** Verify that the proposed code would actually work at runtime - correct API usage, complete data flows, handled edge cases, and sound architecture.
- **Verify agent outputs.** As orchestrator, spot-check what the agents report before including findings in the final review. Agents can misread code or flag false positives.

$ARGUMENTS
