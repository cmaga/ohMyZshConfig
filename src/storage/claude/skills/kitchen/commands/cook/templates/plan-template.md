<!--
Catering's plan (recipes/catering/plan.md), a high-level design. Written to
<docs>/plan.md in the catering order's worktree, untracked. For the user or an
engineering team to review: plain language, no schemas or code (they belong in
the spec), as long as a reviewer needs and no longer. Every section earns its
place: a sentence a reviewer would not act on goes.

- Keep every heading as written. A heading marked "only when it applies" goes
  when nothing applies; a placeholder heading takes the part's own name.
- Name packages, repos, and services, never file paths. Each one named gets a
  row in Relevant Links.
- Write decisions impersonally ("A queue was considered, but..."), never "we"
  or "I".
- An alternative is a "> **Why <the choice>?**" note where the choice comes
  up, never a section of its own. One note asks one question about one
  decision. A note that explains a bullet sits under that bullet. Each reason
  has a confirmed source.
- Delete each placeholder once filled.
-->

# <What is being built> - HLD

## Overview

<The problem: what exists today, what it costs, with the numbers and dates
that show it, and what is coming that makes it worse. Then the design in one
paragraph: what changes, and what each user does afterward.>

### Customers

- **<Who>:** <what they get, or that nothing changes for them>

### Long-Term Vision

<The primary goal, and any future expansion this design leaves room for but
keeps out of scope.>

## Requirements

The following requirements and their prioritization were used to guide design decisions.

### Functional Requirements

| ID | Requirement | Priority |
| --- | --- | --- |
| FR-1 | <What must be true once this ships, one checkable sentence> | <P0, P1, or P2> |

### Non-Functional Requirements

| ID | Requirement | Target |
| --- | --- | --- |
| NFR-1 | <Quality>: <what it means here> | <the measurable bar> |

### Out of Scope

- **<What a reader could reasonably expect this to do>:** <why it is ruled out, and what owns it instead>

## Design Solution

### How It Works

The design has <n> paths, and each does one job:

1. **<Path>.** <What it does, from where to where.>

> **Why <the central choice>?** <Each other option considered, and why it lost.>

```mermaid
<one context diagram: the paths, who uses them, and the outside services they touch>
```

The same flow, start to finish:

```mermaid
<one sequence diagram: the main flow end to end, with what happens on failure>
```

### <One section per path above>

<What the path does, then its decisions and behaviors as bullets.>

- **<A decision or behavior>.** <What it is.>

  > **Why <the choice>?** <The other option, and why it lost.>

```mermaid
<the path's own diagram, numbered steps on its arrows>
```

### Security

<Only when it applies. Who can read, who can write, where credentials come
from, and what stops the setup from being loosened.>

### Knowing When It Breaks

<Only when it applies. What each instance reports, the alarms on it, and who
gets the ticket.>

| Alarm | Fires when | Severity |
| --- | --- | --- |
| <Name> | <The condition and how long it holds> | <Severity> |

### Rolling Back

- **<What went wrong>:** <How it is undone, and what keeps working meanwhile.>

## Deployment

<How the work ships: how many milestones, and what each waits on from the one
before.>

### Where It Deploys

<Only when it applies.>

| Pipeline | Carries | Stages, in order |
| --- | --- | --- |
| <Pipeline> | <What this design adds to it> | <Each stage, and what gates it> |

### <Considerations specific to where it runs>

<Only when it applies. A constraint of the environment that shapes the design,
and how the design meets it.>

### Milestones

#### 1. <Name>

<Where and when it ships.>

- <What ships in it>

## Potential Issues

### Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| <What could go wrong> | <What it costs when it does> | <What prevents it or limits it, or "Accepted" with where the trade-off is argued> |

## Relevant Links

| Resource | Link |
| --- | --- |
| Ticket | [<EPIC>](<its tracker link>) |
| <Package, repo, service, or doc> | [<Name>](<its link>) |

## Revisions

| Date | Author | Description |
| --- | --- | --- |
| <date> | <author> | Initial HLD draft for <team> review |
