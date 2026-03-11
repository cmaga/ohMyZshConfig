# Implementation Plan: {TICKET-KEY} - {Brief Title}

## Meta

- **Jira Ticket:** {TICKET-KEY}
- **Branch:** {BRANCH_PREFIX}{TICKET-KEY}
- **Plan creation date:** {date}

## Executor Instructions

Execute this plan independently without asking questions. Your job is to transform this plan into working, tested, linted, and reviewed code.

**Rules:**

- Stay in scope - Only modify files directly required for this ticket
- Prefer existing patterns - Use patterns already established in the codebase rather than introducing new ones
- Note related issues in your completion summary but do not fix them

**Workflow:**

1. Read and understand this implementation plan
2. Implement all tasks following this plan exactly
3. Final review - ensure code is clean, tests pass, changes follow architecture
4. Push the branch to remote
5. Create PR using git-provider skill targeting the branch specified in Meta
6. Update Jira ticket using jira skill - add PR link comment, move to In Review
7. Complete with attempt_completion summary including:
   - PR link
   - Brief description of changes
   - Any related issues discovered (but not fixed)
   - Any major assumptions made

## Overview

{ What is being done and why}

## Architecture & Design Decisions

{Technical approach including:}

- Patterns from the existing codebase to follow (reference specific files)
- Key architectural decisions and why they were made
- Libraries/tools to use (and which to avoid)
- Data models, API contracts, or schemas if applicable

## Constraints

{Non-negotiable rules the executor MUST follow:}

- **DO NOT modify:** {list files/modules that are off-limits}
- **MUST use:** {specific patterns, libraries, conventions}
- **MUST NOT:** {anti-patterns to avoid, common mistakes}
- **Testing:** {testing framework, coverage expectations, test types}

## Tasks

Each task is an atomic unit of work. One task = one commit. Execute in order.

---

### Task 1: {Short descriptive title}

**Files to create/modify:**

- `path/to/file.ts` - {what to do}
- `path/to/other.ts` - {what to do}

**Reference implementation (required):** `path/to/example.ts` - {follow this pattern/example for X}

**Specification:**

{Detailed description of what to implement. Written so someone unfamiliar with the codebase could do it without questions.}

- Input/output contracts
- Edge cases to handle
- Error handling expectations
- How this integrates with existing code

**Workflow type:** TDD | VERIFY_ONLY

**Workflow:**

For TDD:

1. Create stubs/interfaces - define contracts, follow architecture patterns
2. Write tests against stubs in `path/to/test.ts`:
   - {Happy path - describe input and expected output}
   - {Edge case - describe}
   - {Error case - describe}
3. Implement until tests pass
4. Run tests: `{exact test command}`

For VERIFY_ONLY:

1. Implement following reference pattern
2. Verify: builds, lints, visual check

**Verification:**

- Implementation complete
- Tests passing (if TDD)
- {Additional verification - linting, type checking, etc.}
- Run: `{exact verification command or poject specific script}`

**Commit message:** `{Change type}: {conventional commit message}`

---

### Task 2: {title}

{Same structure as Task 1}

---

### Task N: {Final task}

{Same structure as Task 1}

**Jira update:** Move {TICKET-KEY} to "In Review" after PR is created

---

## Definition of Done

- All tasks completed and committed
- All tests passing: `{test command}`
- Type check passing: `{typecheck command}`
- Lint passing: `{lint command}`
- Branch pushed to remote
- PR created targeting {PR_TARGET}
- Jira ticket moved to "In Review"
- PR link added as comment on Jira ticket
