# Agent Teams Authoring Guide

This guide covers authoring project documentation that supports Agent Teams — not how to use teams directly (that's invoked via natural language prompts).

## When to Author Team Documentation

Author team documentation in CLAUDE.md when your project has:

- Recurring parallel work patterns (same team structure used repeatedly)
- Clear layer boundaries that benefit from explicit documentation
- File ownership rules that prevent conflicts
- Coordination patterns that teams should follow

**Do not author team documentation for:** One-off parallel tasks. Those are handled ad-hoc via natural language prompts.

## What Agent Teams Are

Agent Teams coordinate multiple Claude Code sessions working in parallel. One session is the **team lead** — it decomposes work, spawns teammates, and synthesizes results. Teammates operate independently in their own context windows.

Key characteristics:

- Independent processes with independent context (subagents also have their own context — the difference is communication: subagents only report back to caller, teammates message peer-to-peer)
- Can message each other directly (peer-to-peer)
- Each teammate reads CLAUDE.md independently
- Token usage scales with number of active teammates (~Nx for N teammates)
- Ephemeral — no persistent identity, no memory, no `/resume` (this is why documenting patterns in CLAUDE.md matters)
- Permissions are uniform across all teammates — you cannot restrict tools per-teammate

**Rule of thumb:** If you wouldn't assign the work to multiple humans simultaneously, don't use agent teams.

## Documenting Team Archetypes

When a team pattern is reusable, document it in CLAUDE.md. Include:

1. **Team name** — descriptive identifier
2. **Teammates and roles** — clear, non-overlapping responsibilities
3. **Coordination contract** — what teammates agree on before diverging
4. **File boundaries** — which teammate owns which files/directories
5. **When to use** — trigger conditions for this pattern

### Template

```md
## Team: [Name]

Use for: [trigger conditions]

| Teammate | Responsibility | Files   |
| -------- | -------------- | ------- |
| [Role 1] | [Clear scope]  | [Paths] |
| [Role 2] | [Clear scope]  | [Paths] |
| [Role 3] | [Clear scope]  | [Paths] |

Coordination: [What teammates agree on first, e.g., shared interfaces]
```

### Example: Full-Stack Feature Team

```md
## Team: Full-Stack Feature

Use for: New features touching both API and UI with clear contracts.

| Teammate | Responsibility                | Files                                         |
| -------- | ----------------------------- | --------------------------------------------- |
| Backend  | API routes, service layer, DB | `src/api/`, `src/services/`, `prisma/`        |
| Frontend | React components, state, UI   | `src/components/`, `src/hooks/`, `src/pages/` |
| Tests    | E2E and integration tests     | `tests/`, `*.test.ts`                         |

Coordination: Backend and Frontend agree on API contract (types + endpoints) before diverging.
```

## Standard Archetypes Reference

These are starting templates — adapt to your project's needs:

| Archetype              | Teammates                       | Best for                                 |
| ---------------------- | ------------------------------- | ---------------------------------------- |
| **Code Review**        | Security + Performance + Tests  | PR review with focused lenses            |
| **Full-Stack Feature** | Backend + Frontend + Tests      | New features with clear layer boundaries |
| **Bug Hunt**           | Hypothesis A + B + C            | Debugging with multiple theories         |
| **Architecture**       | Advocate + Critic + Synthesizer | Design decisions, tech evaluations       |
| **Refactor**           | Module A + Module B + Module C  | Large refactors across independent files |

## Documenting File Ownership

File conflicts are the primary failure mode for Agent Teams. Document clear boundaries.

**Alternative: Git worktrees.** Teammates can use git worktrees for full file isolation, eliminating conflict risk entirely. File ownership docs are still useful for clarity but aren't the only mitigation.

```md
## File Ownership (for Agent Teams)

- `src/api/**` — Backend teammate only
- `src/components/**` — Frontend teammate only
- `src/shared/types/**` — Backend creates, Frontend reads
- `tests/**` — Test teammate only
```

Include ownership documentation when:

- Your project has distinct layers with potential overlap
- Multiple teammates might reasonably touch the same files
- You've experienced file conflicts in past team runs

## Documenting Coordination Patterns

For cross-layer work, document what teammates should agree on first:

```md
## Coordination Contracts

### API Features

Before diverging:

1. Backend proposes endpoint paths and request/response shapes
2. Frontend confirms the contract works for UI needs
3. Both proceed independently with shared types in `src/shared/types/`

### Database Changes

1. Backend creates migration and types
2. Frontend waits for type export before touching dependent components
```

**Task dependencies:** The task system supports blocking dependencies natively. Express sequencing as task dependencies rather than prose instructions like "Frontend waits for type export."

**Plan approval pattern:** For high-stakes tasks, teammates can be required to plan in read-only mode until the lead approves. Document this when mistakes are costly.

## Cost and Model Guidance

Include cost-aware recommendations if budget matters:

```md
## Agent Team Cost Guidelines

- Use faster/cheaper models for mechanical work (tests, implementations from spec)
- Use most capable models for architectural decisions, complex reasoning
- Plan first (`/plan`) before spawning teams to reduce token waste
- Keep teams to 2-3 teammates unless task clearly separates into more
```

## Authoring Anti-Patterns

**Vague responsibilities:**

```md
# Bad

- Teammate 1: Work on the feature
- Teammate 2: Help with the feature

# Good

- Teammate 1: API endpoints and service layer
- Teammate 2: React components and state management
```

**Missing file boundaries:**

```md
# Bad (no file guidance, will cause conflicts)

## Team: Feature

- Backend: Build backend
- Frontend: Build frontend

# Good (explicit non-overlap)

## Team: Feature

- Backend: `src/api/`, `src/services/`
- Frontend: `src/components/`, `src/pages/`
```

**Per-teammate tool restrictions:**

```md
# Bad (impossible to enforce — permissions are uniform)

## Team: Feature

- Backend: Can use Write on `src/api/` only
- Frontend: Can use Write on `src/components/` only

# Good (use file boundaries, not tool restrictions)

## Team: Feature

- Backend owns: `src/api/`, `src/services/`
- Frontend owns: `src/components/`, `src/pages/`
```

**Over-documenting ad-hoc teams:**

Don't document one-off team structures. If a pattern won't be reused, invoke it via natural language:

```
Create an agent team to [specific task].
- Teammate 1: [specific responsibility]
- Teammate 2: [specific responsibility]
```

## Self-Check

1. Is this a recurring pattern worth documenting, or a one-off?
2. Are teammate responsibilities non-overlapping?
3. Are file boundaries explicit enough to prevent conflicts?
4. Is the coordination contract clear (what they agree on first)?
5. Have you included model/cost guidance if relevant?
6. Is the documentation concise enough to fit in CLAUDE.md without bloat?
