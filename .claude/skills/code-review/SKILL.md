---
name: /code-review
description: Perform a structured, parallel code review of a branch using a team of reviewer agents, then auto-fix what can be fixed. Use when a branch is ready for review, when code review is requested, or when invoking /code-review with a branch name.
argument-hint: "[branch name]"
disable-model-invocation: false
---

# Team Code Review

## Overview

Coordinate a team of parallel Sonnet reviewer agents to perform a thorough, structured code review of a branch. Run the review as an ultracode Workflow that fans out across complementary review dimensions, adversarially verifies the findings, then applies every fix that can be made unambiguously. The report is a record of what was fixed plus a table of what still needs a decision.

The orchestrator (the main Opus model) is in command. The Sonnet subagents are workers: they gather evidence and propose findings. Every finding they return is a claim to be checked, not a fact. The orchestrator confirms, overrules, merges, re-severities, and decides what gets fixed. Nothing reaches the report on a subagent's word alone.

## Workflow

### Step 1: Identify the Review Target

Determine what to review based on user input:

- If a **branch name** is provided, use that branch.
- If **nothing** is provided, use the current branch (`git branch --show-current`).
- The base branch is the branch the task branch was cut from - usually `develop`, but a task cut from a long-lived feature branch is reviewed against that feature branch. Call it `<base>` below.
- Run `git fetch origin <base>` to ensure refs are up to date.

The branch and its commits are the whole input. There is no PR to look up and no bot review comments to triage.

### Step 2: Gather Context

Before spawning reviewers, collect key information:

- Run `git log --oneline <base>..HEAD` to list all commits on the branch (reviewers need ALL commits, not just the latest).
- Run `git diff <base>...HEAD --stat` to size the change: how many files, how much churn, how much of it is new logic versus content or config.
- Read `CLAUDE.md` so the orchestrator can judge subagent findings against the standards rather than trusting them.
- Note the branch name for the report (e.g., `task/widget-age-footer`). This project does not use ticket numbers.

### Step 3: Run the Review Workflow

Perform the review with an ultracode Workflow (the `Workflow` tool), not one-off `Agent` calls. Structure it so **Sonnet** subagents run in parallel, each owning one slice of the review, then adversarially verify the findings before consolidating:

- Set each stage's model per `.claude/rules/subagent-models.md`: finders and verifiers are Sonnet (`model: 'sonnet'`); mechanical stages such as listing files or sizing the diff can run on Haiku.
- **Use as many subagents as the change actually needs.** Scale the fan-out to the size of the diff, the number of files touched, and how much real logic is in it. This overrides the session's default workflow-size guideline: a large or logic-heavy branch should get a wide fan-out, splitting a dimension across several subagents so each owns a bounded set of files rather than skimming everything. A small, mechanical change should stay lean. Err on the side of more coverage when the diff is large.
- Feed each finder the same context: the branch, the full commit list, its assigned files, and the coding standards. Have each return structured findings (a JSON `schema`) so the orchestrator does not have to parse prose.
- Adversarially verify: for each candidate finding, spawn a Sonnet verifier subagent prompted to refute it. Drop findings that do not survive verification. Prefer `pipeline()` so verification of one dimension's findings starts as soon as that dimension reports, rather than waiting on a barrier.
- Add a completeness-critic subagent on larger diffs: give it the file list and the findings so far, and have it name what was not covered.
- The Workflow returns the surviving, verified findings; the orchestrator takes over at Step 5.

### Step 4: Review Dimensions

Cover these complementary review dimensions. On a large diff, split any dimension across several subagents by file or by subsystem rather than giving one subagent the whole surface.

**Dimension 1 - Correctness & Architecture:**
- Logic errors, broken control flow, missing error handling
- API contract violations, incorrect data transformations
- Retain cycles in closures (missing `[weak self]`, incorrect `strongSelf` naming)
- Thread safety (main thread UI updates, shared state access; `SensorReader` reads on its own queue and calls back on the main thread)
- App and widget boundaries: the widget extension is sandboxed and only reads the `ReadingsSnapshot` the app saves to the shared app group, so anything new it shows must reach that snapshot
- Architectural concerns, MVVM separation of concerns
- Security issues (exposed secrets, injection risks, auth gaps)
- Build-breaking issues (missing imports, type errors, broken references)
- Deprecated API usage (must stay within the project's deployment target: flag APIs deprecated at or below the `MACOSX_DEPLOYMENT_TARGET` in the project, and do not assume a minimum macOS version that the project does not set)
- `.xcodeproj/project.pbxproj` changes: minimal edits only, no reformatting, correct whitespace
- Over-abstraction: helpers, protocols, or generic layers introduced for a single caller

**Dimension 2 - CLAUDE.md Compliance:**

Treat this as a mandatory line-by-line sweep, not a spot check.

The subagent must:
1. Read `CLAUDE.md` in full first, specifically the **Code Style** section.
2. Walk the numbered style rules **in order**, and for each rule, scan every added or changed line in the diff for a violation. Do not sample. Do not stop early because the first few files looked clean.
3. Report the rule it violates by name with every finding (e.g., "Rule: Type Declarations", "Rule: Else and Catch on Their Own Line") so the orchestrator can confirm it against the source text.
4. Also check the non-style CLAUDE.md sections that apply to the diff: file headers on new Swift files (the change author's name, never an AI name), pbxproj editing rules, project structure, and the technical stack constraints.

**Dimension 3 - Quality & Consistency:**
- Consistency with existing codebase patterns for anything CLAUDE.md does not spell out
- Naming clarity
- Dead code introduced or left behind by the change
- Complexity that is not carrying its weight

**Note on repetition:** this project prefers repeated code over clever code. Do **not** report DRY violations as findings. Two or three similar blocks that each stay readable and narrowly scoped are the preferred outcome. Only flag duplication when it is genuinely a correctness hazard, such as the same constant or rule defined in two places that must stay in sync and will silently drift. Conversely, do flag the opposite problem: an abstraction pulled out for a single caller, or a helper made so general that it no longer says what it is for.

Every finder subagent should:
- Read CLAUDE.md first for coding standards
- Run `git diff <base>...HEAD` to see all changes
- Read full files when more context is needed around a change
- Examine all commits, not just the latest
- Categorize each finding as Must Fix, Should Fix, or Nice-to-Have
- Return findings back to the orchestrator with a file path and line number

### Step 5: Verify and Consolidate

The orchestrator owns this step. Subagent output is raw material.

- **Spot-check claims.** If a subagent says a line violates a rule, read the line and the rule and confirm it. Subagents miscount lines and misremember standards.
- **Dismiss false positives.** Drop anything that is actually correct, or that CLAUDE.md does not actually say.
- **Catch what was missed.** Given what was read in Step 2, consider whether an obvious issue went unreported. Investigate it directly rather than spawning another round for something small.
- **Resolve conflicts.** When two subagents disagree about the same code, read it and decide.
- **Deduplicate.** Merge overlapping findings into single items.
- **Resolve severity.** When subagents categorize the same issue differently, take the higher severity unless there is a clear reason to downgrade.
- **Prioritize.** Order items within each category by impact.
- **Anchor everything.** Every surviving finding carries a file path and, where possible, a line reference and code snippet.

CLAUDE.md violations in code this branch adds or changes are **Should Fix at minimum**, never Nice-to-Have.

### Step 6: Delete Dead Code

Dead code found during the review is deleted as part of the review, without asking first. It does not go in the report as a suggestion.

Before deleting anything, **prove it is dead**:
- Grep the whole repository for the symbol, including every target the Xcode project lists (`fanny-macOS`, `fanny-macOS-widget-extension`, which also compiles `fanny-shared/`, and `fanny-macOS-tests`). Use the targets the current project file actually defines.
- Check for non-Swift references: asset catalog names, `project.pbxproj`, `Info.plist` files, String Catalogs, the FAQ JSON (`FAQDestination` names), `config.example.json`, App Intents and `AppShortcuts` phrases, and anything resolved by string name at runtime.
- Check for `@objc`, selector, and key-value-coding usage, where the call site is a string rather than a symbol.
- Check protocol conformances and overrides, where the caller is the framework rather than our code.

If any of those turn up a live reference, it is not dead - leave it alone. If the evidence is ambiguous, leave it alone and raise it as a Should Fix finding instead. Deleting used code is far worse than leaving a dead symbol behind, so the bar is proof, not suspicion.

Never `git restore`, `git checkout`, or `git clean` a file. Removals are surgical edits to the specific dead symbol.

### Step 7: Auto-Fix the Findings

For every consolidated finding, the orchestrator decides on the fix and then applies it. This is not a proposal step - the fixes land in the working tree.

**Apply the fix when** the correct change is unambiguous and self-contained: CLAUDE.md style violations, naming, missing `[weak self]`, `!` to `== false`, missing explicit types, MARK placement, `print` to `Log`, header blocks, `.init(...)` shorthand, misplaced `else`, a clear off-by-one, a missing `guard`, a wrong constant, and anything else where reading the code tells you exactly what it should say.

**Leave it for the user when** the fix needs a judgment call the code cannot answer: a behavior or product decision, an architectural restructure, a change that would alter what the user sees or how a feature works, a fix with more than one defensible approach, or anything touching signing, provisioning, or release configuration.

After applying the fixes:
- Re-read each edited region to confirm the change is correct and the surrounding style still matches.
- Commit the applied fixes as a single commit with a short descriptive message.
- Items that were not auto-fixed go in the final table (Step 8). They stay in the tree untouched.

### Step 8: Present the Report

Deliver the review using the output format below. It has two halves: what was fixed, and what still needs the user.

The final table lists **only** the items that were not auto-fixed, grouped by section (Must Fix, Should Fix, Nice-to-Have), numbered continuously so the user can reply with numbers to say which ones to take on.

## Output Format

Present the final review as follows:

```markdown
# Code Review: [branch name]

**Branch:** `<branch-name>`
**Base:** `<base>`
**Commits reviewed:** <count>
**Reviewers:** <count> Sonnet subagents across <count> dimensions

---

## Auto-Fixed
> Applied directly to the branch and committed. No action needed.

- **[Short title]** - `path/to/file.swift:L42` - [what was wrong and what it is now]
- ...

## Dead Code Removed
> Verified unreferenced across every target before deletion.

- **[Symbol or block]** - `path/to/file.swift:L88` - [what it was and how it was proven dead]
- ...

---

## Needs Your Decision

### Must Fix
> Would cause bugs, broken builds, data corruption, or security vulnerabilities.

| # | Finding | Location | Why it was not auto-fixed |
|---|---------|----------|---------------------------|
| 1 | [Short description] | `file.swift:L42` | [the judgment call needed] |

### Should Fix
> Missing validation, error handling, standards violations that need a call.

| # | Finding | Location | Why it was not auto-fixed |
|---|---------|----------|---------------------------|
| 2 | [Short description] | `file.swift:L15` | [the judgment call needed] |

### Nice-to-Have
> Optional improvements.

| # | Finding | Location | Why it was not auto-fixed |
|---|---------|----------|---------------------------|
| 3 | [Short description] | `file.swift:L88` | [the judgment call needed] |

---

**Summary:** X issues auto-fixed, Y dead symbols removed, Z awaiting a decision.
```

Tell the user to reply with the numbers they want taken on.

If a section has no remaining items, include it with "None." to make it explicit. If nothing was auto-fixed or no dead code was found, say so in that section rather than dropping it.

## Principles

- **The orchestrator is in command.** Sonnet subagents propose; the Opus orchestrator disposes. Verify their claims before acting on them, overrule them when they are wrong, and own the final report.
- **Scale the team to the change.** A large or logic-heavy diff deserves a wide fan-out with bounded per-agent scope. Do not under-staff a big review.
- **Review all commits.** Look at the full set of changes on the branch, not just the most recent commit. Earlier commits may introduce issues that later commits do not fix.
- **CLAUDE.md is not optional.** If CLAUDE.md states a rule, it is enforced in code this branch adds or changes, no matter what the rest of the codebase looks like. Sweep its rules in order rather than reviewing on feel.
- **Existing patterns still win where CLAUDE.md is silent.** An unwritten convention that matches the rest of the codebase is not a violation. That leniency covers unwritten conventions only, never explicit CLAUDE.md rules.
- **Repetition beats cleverness.** Do not chase DRY. Prefer a repeated block that stays readable and narrowly scoped over a shared helper that widens until it loses its purpose.
- **Prove before deleting.** Dead code goes without asking, but only after grepping every target and every string-keyed reference. Ambiguity means leave it.
- **Fix what you can, table what you cannot.** Mechanical corrections land in the tree. Judgment calls go to the user with the reason they need a decision.
- **Be practical.** The review is about this branch's changes, not a full codebase audit.
- **Be specific.** Every finding must include a file path. Vague findings like "consider improving error handling" without pointing to specific code are not useful.
- **Do not build.** Per CLAUDE.md, do not attempt to compile or build the project. Verify correctness by reading and analyzing the code directly.

$ARGUMENTS
