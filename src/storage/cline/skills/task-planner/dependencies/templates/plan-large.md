# {TICKET-KEY}: {Title}

## Size: large

## Branch: {TICKET-KEY}

## Who You Are

You are an orchestrator. Read this plan, identify sub-tasks and their dependencies, then spawn workers to execute them.

**Rules:**

- Never write application code yourself — delegate to workers
- Hold only plan summaries and worker status in context — not implementation details
- Respect dependency ordering between sub-tasks
- If a worker fails twice, escalate to an Opus worker
- If the plan is incomplete or contradictory, reject it back to the user

## Context

{Paragraph: what this change does and why it matters}

### Architectural context

- {Key architectural detail with file reference}
- {Auth/data/API patterns relevant to this change}

## Sub-tasks

### Sub-task A: {Title}

**Files:** `{path}` (create | modify), `{path}` (modify)
**Steps:**

1. {Step with specific implementation detail}
2. {Step with verification command}

**Reference:** `{path/to/example}` for pattern
**Depends on:** Nothing | Sub-task X
**Verification:** `{command that proves this sub-task is done}`

### Sub-task B: {Title}

**Files:** `{path}`
**Steps:**

1. {Step}

**Depends on:** Sub-task A
**Verification:** `{command}`

### Sub-task C: {Title}

**Files:** `{path}`
**Steps:**

1. {Step}

**Depends on:** Sub-task A
**Verification:** `{command}`

### Sub-task D: {Title}

**Files:** `{path}`
**Steps:**

1. {Step}

**Depends on:** Sub-tasks B and C
**Verification:** `{command}`

## Parallelization

- **Independent (can run in parallel):** Sub-tasks B, C
- **Sequential:** A -> (B, C) -> D

## Edge cases (from review)

- {Edge case 1: scenario -> expected behavior}
- {Edge case 2: scenario -> expected behavior}

## Test matrix

| Scenario     | Expected           |
| ------------ | ------------------ |
| {scenario 1} | {expected outcome} |
| {scenario 2} | {expected outcome} |
| {scenario 3} | {expected outcome} |

## Pre-existing UI

> Optional -- include only if UI was scaffolded during planning and already committed to the worktree.

- `{path/to/component}` -- already created with mock data, do not recreate
- `{path/to/styles}` -- approved by user, modify only to wire real data
- **What to wire:** replace hardcoded/mock data with {real data source}

## Boundaries — do NOT touch

- `{path/to/off-limits-file}` — {reason}
- `{module}` — out of scope
- Do not add new dependencies

## Done when

- All sub-tasks complete and integrated
- All new and existing tests pass
- Lint/format passes
- Build succeeds
- Branch pushed
- PR created targeting main
