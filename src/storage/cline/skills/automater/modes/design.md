# Design Mode

Create an implementation plan for a given jira ticket.
Plans are fully delegated to CLI executors with no additional context beyond the plan and codebase.

## Critical Rules

1. **Never assume — verify.** Read files before referencing them.
2. **The plan is the contract.** Omissions will not be implemented.
3. **Examples over descriptions.** Reference `src/path/to/example.ts`, not "RESTful conventions."

## Process

### Step 1: Investigate

Gather context without commentary. Use terminal commands and `read_file`.

Use `use_subagents` for parallel discovery in large codebases:

### Step 2: Clarify

Ask targeted questions only when:

- Requirements are ambiguous
- Multiple valid approaches exist
- Assumptions need confirmation

Bundle questions. Give yourself a confidence score. Proceed when confidence score is 10/10.

### Step 3: Draft

Present high-level changes for user iteration:

1. Types/interfaces
2. Data layer
3. Business logic
4. API
5. UI

For testable code, include non-obvious edge cases in the plan.

### Step 4: Write Plan

Write to: `.cline-project/skills/automater/plans/{TICKET-KEY}-plan.md`

Use [plan-template.md](../dependencies/templates/plan-template.md).

Before finalizing:

- Does the plan include all context necessary to perform the tasks?
- Dependency order correct?
- All acceptance criteria covered?
- Reference files exist for every pattern?
