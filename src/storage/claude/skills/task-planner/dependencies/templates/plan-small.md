# {TICKET-KEY}: {Title}

## Size: small

## Context

{One sentence: what and why}

## Card Strategy

### Card 1: {name}

- **Type**: autonomous
- **Scope**: {what this card accomplishes}
- **Files**: `{path/to/file}`
- **What to change**: {description of change}
- **Done when**:
  - {Acceptance criterion 1}
  - {Acceptance criterion 2}
  - Existing tests still pass

<!-- If UI prototyping was requested, use this 2-card structure instead:

### Card 1: Prototype UI for {feature} (interactive)

- **Type**: interactive (requires human review)
- **Scope**: Scaffold UI with mock data, start dev server, iterate with user
- **Files**: `{path/to/component}`
- **Prototype targets**:
  - {What to build visually}
- **Done when**: User approves visual output

### Card 2: Wire {feature} logic

- **Type**: autonomous
- **Blocked by**: Card 1
- **Scope**: Wire real data and logic to UI created in Card 1
- **Files**: `{path/to/file}`
- **Implementation**: Read the component files committed by Card 1 on the branch. Do NOT assume component names or prop shapes — inspect the actual files.
- **What to change**: {description}
- **Done when**:
  - {Acceptance criteria}
  - Existing tests still pass
-->

## Cross-Ticket Dependencies

None
