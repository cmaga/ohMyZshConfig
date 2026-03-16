# Implementation Plan: {TICKET-KEY}

## Meta

- **Ticket:** {TICKET-KEY}
- **Branch:** {TICKET-KEY}
- **Created:** {YYYY-MM-DD}

## Who You Are

Execute this plan independently without asking questions.
Your job is to transform this plan into working, tested, linted, and reviewed code.

**Critical Rules:**

- Stay in scope - Only modify files directly required for this ticket
- Prefer existing patterns - Use patterns already established in the codebase rather than introducing new ones
- Fix any trivial issues encountered that do not involve architectural decisions

## Overview

{One paragraph: what and why}

## Architecture

- **Pattern reference:** `src/modules/users/users.controller.ts`
- **Data model:** {if applicable}
- **Key decisions:** {bullet list}

## Constraints

- **DO NOT modify:** {files/modules off-limits}
- **MUST use:** {patterns, libraries}
- **Testing:** {framework, coverage expectations}

## Tasks

Execute in order. One task = one commit.

---

### Task 1: {Title}

**Files:**

- `path/to/file.ts` — {action}

**Reference:** `path/to/example.ts`

**Spec:**
{What to implement. Input/output contracts. Edge cases. Error handling.}

**Workflow:** TDD | VERIFY_ONLY

For TDD:

1. Create stubs/interfaces
2. Write tests: happy path, edge case, error case
3. Implement until green
4. `npm test -- path/to/test.ts`

**Commit:** `feat(module): description`

---

### Task N: {Title}

{Same structure}

---

## Definition of Done

- All tasks committed
- Builds completing succesfully
- All tests passing
- Linting/formatting scripts run and any issues fixed
- Branch pushed
- PR created targeting {PR_TARGET}
- Jira moved to "In Review"
- PR link added to Jira
