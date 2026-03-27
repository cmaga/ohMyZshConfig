# {TICKET-KEY}: {Title}

## Size: medium

## Branch: {TICKET-KEY}

## Who You Are

Execute this plan independently without asking questions.
Your job is to transform this plan into working, tested, linted code.

**Rules:**

- Stay in scope — only modify files listed below
- Use existing patterns — reference files are your style guide
- Fix trivial issues encountered without architectural decisions
- If something is ambiguous, fail loudly with a clear error rather than guessing

## Context

{One paragraph: what and why}

## Files to touch

- `{path/to/file}` — {action: create | modify | delete}
- `{path/to/file}` — {action}

## Steps

1. {Step description}
   - **Files:** `{path}`
   - **Reference:** `{path/to/example}` for pattern
   - **Spec:** {What to implement, input/output contracts, edge cases}

2. {Step description}
   - **Files:** `{path}`
   - **Spec:** {Details}

## Pre-existing UI

> Optional -- include only if UI was scaffolded during planning and already committed to the worktree.

- `{path/to/component}` -- already created with mock data, do not recreate
- `{path/to/styles}` -- approved by user, modify only to wire real data
- **What to wire:** replace hardcoded/mock data with {real data source}

## Constraints

- **DO NOT modify:** {files/modules off-limits}
- **DO NOT add dependencies** unless explicitly listed
- **Pattern reference:** `{path/to/existing/example}`

## Test expectations

- {Test scenario 1: input -> expected output}
- {Test scenario 2: edge case -> expected behavior}
- {Test scenario 3: error case -> expected error}

## Done when

- All new tests pass
- Existing tests still pass
- Lint/format passes
- Branch pushed
- PR created targeting main
