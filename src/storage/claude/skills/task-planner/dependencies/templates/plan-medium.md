# {TICKET-KEY}: {Title}

## Size: medium

## Context

{One paragraph: what and why}

## Card Strategy

### Card 1: {name}

- **Type**: autonomous
- **Blocked by**: none
- **Scope**: {what this card accomplishes}
- **Files**:
  - `{path/to/file}` — {action: create | modify | delete}
  - `{path/to/file}` — {action}
- **Implementation**:
  1. {Step description}
     - **Reference**: `{path/to/example}` for pattern
     - **Spec**: {What to implement, input/output contracts, edge cases}
  2. {Step description}
     - **Spec**: {Details}
- **Constraints**:
  - DO NOT modify: {files/modules off-limits}
  - DO NOT add dependencies unless explicitly listed
  - Pattern reference: `{path/to/existing/example}`
- **Test expectations**:
  - {Test scenario 1: input -> expected output}
  - {Test scenario 2: edge case -> expected behavior}
  - {Test scenario 3: error case -> expected error}
- **Done when**:
  - {Verifiable condition 1}
  - {Verifiable condition 2}
  - All new tests pass
  - Existing tests still pass
  - Lint/format passes

### Card 2: {name} (if needed)

- **Type**: autonomous
- **Blocked by**: Card 1
- **Scope**: {what this card accomplishes}
- **Files**: `{path}`
- **Implementation**: {steps}
- **Done when**: {criteria}

<!-- If UI prototyping was requested, use this structure:

### Card 1: Prototype UI for {feature} (interactive)

- **Type**: interactive (requires human review)
- **Blocked by**: none
- **Scope**: Scaffold UI components with mock data, start dev server, iterate with user
- **Files**: `{path/to/components}`
- **Prototype targets**:
  - {Component/page 1}
  - {Component/page 2}
- **Done when**: User approves visual output in dev server

### Card 2: Wire {feature} data layer + logic

- **Type**: autonomous
- **Blocked by**: Card 1
- **Scope**: Wire real data to UI components created in Card 1
- **Files**: `{path/to/api}`, `{path/to/components}`
- **Implementation**: Read the component files committed by Card 1 on the branch. Do NOT assume component names or prop shapes — inspect the actual files. Then:
  1. {Wire real API calls}
  2. {Add error/loading states}
  3. {Write tests}
- **Done when**:
  - {Acceptance criteria}
  - All tests pass
  - Lint/format passes
-->

## Cross-Ticket Dependencies

None
