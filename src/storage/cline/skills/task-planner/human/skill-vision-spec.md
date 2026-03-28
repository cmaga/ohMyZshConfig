# Task Planner Vision Spec (v2)

## Overview

A planning workflow where **Cline handles all planning** and **Cline Kanban handles all execution**. Plans are written in Cline as markdown files containing a card strategy. The Kanban system reads the plan, creates cards with dependency chains, assigns worktrees, and runs tasks in parallel.

The goal: you stay in Cline planning the next ticket while Kanban executes already-planned work in the background. Planning never stops. Execution never waits.

---

## Architecture

There are three planning tiers based on ticket size. Each tier increases planning depth. Execution is always handled by Kanban — the planner does not concern itself with how cards are executed.

| Tier   | Planning depth                                      | Output                              |
| ------ | --------------------------------------------------- | ----------------------------------- |
| Small  | Minimal — ticket description is the plan            | 1 card, basic instructions          |
| Medium | Steps, files, constraints, test expectations        | 1-3 cards with dependency links     |
| Large  | Full plan with review gate, edge cases, test matrix | 2-5+ cards with parallelization map |

---

## User Interaction Flow

### Triage

The user opens Cline and pulls their assigned tickets via the Jira skill. They review each ticket and tag it as small, medium, or large based on complexity. This is a judgment call — the skill does not auto-classify.

### Small Tickets

```
You + Cline: read ticket, tag as small
  |
  v
Cline writes plan with card strategy
  |
  v
Plan on disk -> Kanban creates card -> card executes -> PR created
```

**How it feels:**

1. You're in Cline. You say "plan STAX-42 small".
2. Cline fetches the ticket, you glance at it, say "go".
3. Cline writes a plan file to disk.
4. You're done. Move to the next ticket. Kanban handles execution.

**You are free after step 3.**

### Medium Tickets

```
You + Cline: understand ticket, agree on approach
  |
  v
Cline writes plan with card strategy (1-3 cards)
  |
  v
Plan on disk -> Kanban creates cards -> cards execute (parallel where possible) -> PR created
```

**How it feels:**

1. You're in Cline. You pull up the ticket.
2. You and Cline discuss it — what files, what approach, any gotchas.
3. If there are UI changes, Cline asks if they should be prototyped as an interactive card.
4. Cline writes the plan to disk.
5. You move to the next ticket. Kanban handles execution.

**You are free after step 4.** Review happens asynchronously whenever you're ready.

### Large Tickets

```
You + Cline: deep understanding of ticket
  |
  v
You + Cline: agree on approach, card boundaries
  |
  v
Cline writes draft plan
  |
  v
Cline review subagents vet the plan (security, architecture)
  |
  v
You review findings, adjust if needed
  |
  v
Cline writes final plan with card strategy (2-5+ cards, parallelization map)
  |
  v
Plan on disk -> Kanban creates cards with dependency chains -> cards execute in parallel -> PR created
```

**How it feels:**

1. You're in Cline. You pull up a complex ticket.
2. You and Cline go deep — requirements, edge cases, architectural implications.
3. If there are UI changes, Cline asks if they should be prototyped.
4. Cline writes a draft plan.
5. Cline runs review subagents (security, architecture). You review their findings.
6. Cline finalizes the plan.
7. You're done. Move to the next ticket.

**You are free after step 6.** Kanban manages card creation, dependency sequencing, parallel execution, and PR creation.

---

## Key Concepts

### Cards

Cards are the unit of work. Each card:

- Gets its own worktree
- Runs independently in Kanban
- Has a type: **autonomous** (no human interaction) or **interactive** (requires human review)
- Can be blocked by other cards via dependency links

### Dependency Chains

Cards can be linked so one blocks another. When Card A completes, Card B starts automatically. This enables fully autonomous chains where one task's output feeds into the next.

Cards that depend on another card's output should read the actual files produced rather than assuming exact names or structure.

### Cross-Ticket Dependencies

If ticket B's work depends on cards from ticket A, the plan notes this. Kanban can link cards across tickets.

### UI Prototyping Pattern

When a ticket involves significant UI changes:

1. During planning, Cline asks the user if UI should be prototyped.
2. If **yes**: Card 1 becomes an interactive prototype card. The user reviews in the dev server and iterates (potentially taking over the session). Once approved, Card 2+ handle the backend/wiring work, blocked by Card 1.
3. If **no**: UI changes are described textually in normal autonomous cards.

This separates the subjective (how it looks) from the deterministic (how it works).

---

## Context Management

The plan file is the only bridge between Cline and Kanban.

```
Cline (planning)         Plan file (on disk)        Kanban (execution)
  Full project context  -->  2-20k tokens  -->  Cards with isolated scope
```

**Key rules:**

- Cline's project context never crosses into execution. The plan file is the interface.
- The plan carries just enough for an executor to implement without needing full project understanding.
- Each card gets its own context (worktree + card instructions). Cards don't share context.
- Plans are implementation-focused: no Jira transitions, no devops, no PR creation instructions.

---

## Plan File Format

All plans are markdown files with a Card Strategy section. The planning skill produces the correct format based on ticket size. See `dependencies/templates/` for the templates.

Common structure:

```markdown
# {TICKET-KEY}: {Title}

## Size: {small|medium|large}

## Context

{What and why}

## Card Strategy

### Card 1: {name}

- **Type**: autonomous | interactive
- **Blocked by**: none | Card N
- **Scope**: {what this card accomplishes}
- **Files**: {paths}
- **Implementation**: {steps}
- **Done when**: {criteria}

## Cross-Ticket Dependencies

{If any}
```

Plans are written to `./plans/` relative to the repo root. Naming convention:

```
plans/
  plan-STAX-42-small.md
  plan-STAX-78-medium.md
  plan-STAX-112-large.md
```

The `plans/` directory is gitignored.

---

## What This System Does NOT Do

- **Execute code.** Cline writes plans. Kanban executes them.
- **Manage worktrees.** Kanban creates and cleans up worktrees per card.
- **Manage Jira.** Jira transitions are handled separately via the Jira skill.
- **Auto-classify tickets.** The user decides if a ticket is small, medium, or large.
- **Auto-merge.** PRs are created but never auto-merged. The user reviews and merges.
- **Pass system prompts.** No custom system prompts are passed to executors. Cards contain all instructions in natural language.
