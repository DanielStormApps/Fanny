---
name: /write-plan
description: write a new plan md in plans folder
disable-model-invocation: false
---

Write a comprehensive implementation plan based on the requirements described below. Use ultrathink mode. Follow these instructions precisely:

1. **Research first.** Explore the codebase thoroughly before writing anything. Read every relevant file. Trace call chains, delegate patterns, and data flow end-to-end. Reference exact file paths and line numbers. Assume nothing - verify everything by reading the code.

2. **Create the plan file.** Add a new markdown file to the `plans/` directory (create it if it does not exist yet). Choose a clear, descriptive kebab-case filename (e.g., `feature-name-implementation.md`). Use your best judgment for the name.

3. **Structure the plan** with these sections:
   - **Overview** - What this plan accomplishes and why. Include `**Status:** Not Started`.
   - **Current State** - How the relevant code works today, with file paths, line numbers, and code snippets. Trace the full flow.
   - **Target Behavior** - What should change and how it should work when complete.
   - **File Changes** - Table of files to modify and/or create, with a summary of changes per file.
   - **Implementation** - Organized into logical phases. Each phase should have a clear title, the files it touches, and detailed before/after code showing exact changes. Phases should be ordered so each builds on the previous.
   - **Implementation Checklist** - Mirror the phases with `- [ ]` checkbox items for tracking progress.
   - **Dependencies** - Table of existing components being reused (component, location, role).
   - **Out of Scope** - Explicit list of what this plan intentionally does not cover.
   - Additional sections (Edge Cases, Design Decisions, Notes) as warranted.

4. **Quality standards:**
   - Every file path, method name, property name, and line number must come from actually reading the code - never guess.
   - Code snippets must match the project's Swift style (explicit types, `else` on its own line, `guard` for early exits, no `+=`, etc.).
   - Phases should be small enough to implement and commit independently.
   - The plan should be detailed enough that someone could implement it without asking questions.

5. **Do not stop to ask questions.** Make reasonable decisions and document your rationale in the plan.

6. **When finished**, commit the plan file and push. Reply here with the plan filename and a brief summary of what it covers.

$ARGUMENTS
