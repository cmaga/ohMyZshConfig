# {TICKET-KEY}: {Title}

## Size: large

## Context

{Paragraph: what this change does and why it matters}

### Architectural context

- {Key architectural detail with file reference}
- {Auth/data/API patterns relevant to this change}

## Card Strategy

### Card 1: {name}

- **Type**: autonomous
- **Blocked by**: none
- **Scope**: {what this card accomplishes}
- **Files**:
  - `{path}` — {create | modify}
  - `{path}` — {modify}
- **Implementation**:
  1. {Step with specific implementation detail}
  2. {Step with verification command}
- **Reference**: `{path/to/example}` for pattern
- **Verification**: `{command that proves this card is done}`
- **Done when**: {specific observable outcome}

### Card 2: {name}

- **Type**: autonomous
- **Blocked by**: Card 1
- **Scope**: {what this card accomplishes}
- **Files**: `{path}`
- **Implementation**:
  1. {Step}
- **Verification**: `{command}`
- **Done when**: {outcome}

### Card 3: {name}

- **Type**: autonomous
- **Blocked by**: Card 1
- **Scope**: {what this card accomplishes}
- **Files**: `{path}`
- **Implementation**:
  1. {Step}
- **Verification**: `{command}`
- **Done when**: {outcome}

### Card 4: {name}

- **Type**: autonomous
- **Blocked by**: Cards 2 and 3
- **Scope**: {integration / final wiring}
- **Files**: `{path}`
- **Implementation**:
  1. {Step}
- **Verification**: `{command}`
- **Done when**: {outcome}

## Parallelization

- **Independent (can run in parallel)**: Cards 2, 3
- **Sequential**: Card 1 -> (Cards 2, 3) -> Card 4

<!-- If UI prototyping was requested, Card 1 becomes:

### Card 1: Prototype UI for {feature} (interactive)

- **Type**: interactive (requires human review)
- **Blocked by**: none
- **Scope**: Scaffold UI components with mock data, start dev server, iterate with user
- **Files**: `{path/to/components}`
- **Prototype targets**:
  - {Component/page 1}
  - {Component/page 2}
- **Done when**: User approves visual output in dev server

Subsequent cards are blocked by Card 1 and must read Card 1's actual output files rather than assuming component names or prop shapes.
-->

## Edge cases (from review)

- {Edge case 1: scenario -> expected behavior}
- {Edge case 2: scenario -> expected behavior}

## Test matrix

| Scenario     | Expected           |
| ------------ | ------------------ |
| {scenario 1} | {expected outcome} |
| {scenario 2} | {expected outcome} |
| {scenario 3} | {expected outcome} |

## Boundaries — do NOT touch

- `{path/to/off-limits-file}` — {reason}
- `{module}` — out of scope

## Done when

- All cards complete
- All new and existing tests pass
- Lint/format passes
- Build succeeds

## Cross-Ticket Dependencies

None
