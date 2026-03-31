# Feature Selection Guide

Before authoring, determine which Claude feature fits the user's problem. Walk through these questions interactively.

## Question 1: What triggers this?

Ask: "When should Claude use this information or execute this behavior?"

| Answer                                                   | Feature Direction                          |
| -------------------------------------------------------- | ------------------------------------------ |
| "Every session, always available"                        | → CLAUDE.md or Rules (see follow-up below) |
| "Only when working on specific files/directories"        | → Rules (path-scoped)                      |
| "Only when the task is relevant"                         | → Skill                                    |
| "Only when I explicitly ask for it"                      | → Skill (`disable-model-invocation: true`) |
| "Automatically on specific events"                       | → Hook                                     |
| "In a separate context, isolated from main conversation" | → Subagent                                 |
| "Multiple perspectives working in parallel"              | → Agent Team                               |

**Follow-up for "always available":** Is it a focused, modular concern (testing, security, API conventions)? → Rules. Is it cross-cutting project context (stack, commands, architecture)? → CLAUDE.md.

## Question 2: Is this deterministic or requires judgment?

Ask: "Does this need Claude's reasoning, or is it a repeatable script?"

| Answer                                                      | Feature Direction     |
| ----------------------------------------------------------- | --------------------- |
| Deterministic (linting, formatting, validation)             | → Hook (command type) |
| Requires judgment but simple decision                       | → Hook (prompt type)  |
| Requires judgment with tool access, tied to lifecycle event | → Hook (agent type)   |
| Requires judgment with tool access, on-demand               | → Subagent or Skill   |
| Requires multiple perspectives                              | → Agent Team          |

## Question 3: Context scope?

Ask: "How much context does this need? Does it need conversation history?"

| Answer                           | Feature Direction                 |
| -------------------------------- | --------------------------------- |
| Needs full conversation context  | → Skill or CLAUDE.md              |
| Fresh start is fine or preferred | → Subagent (`context: fork`)      |
| Needs own persistent memory      | → Subagent (with `memory:` field) |
| Multiple independent contexts    | → Agent Team                      |

## Feature Comparison Matrix

| Feature    | Always Loaded | User Invoked | Auto Triggered | Own Context | Parallel         |
| ---------- | ------------- | ------------ | -------------- | ----------- | ---------------- |
| CLAUDE.md  | Yes           | -            | -              | No          | No               |
| Rules      | Conditional\* | -            | -              | No          | No               |
| Skill      | No            | Optional\*\* | Yes\*\*\*      | No\*\*\*\*  | No               |
| Subagent   | No            | Yes          | Yes\*\*\*      | Yes         | Background only  |
| Agent Team | No            | Yes          | No             | Yes (each)  | Yes              |
| Hook       | No            | -            | Yes            | N/A         | Concurrent**\*** |

**Footnotes:**

\* Rules without `paths:` frontmatter are always loaded. Rules WITH `paths:` frontmatter are parsed at startup but only activate when Claude works on matching files.

\*\* Skills with `disable-model-invocation: true` are user-invoked only via `/skill-name`.

\*\*\* Skills trigger via description matching on the Skill tool; Subagents trigger via description matching on the Task/Agent tool.

\*\*\*\* Skills with `context: fork` delegate to a subagent, so the skill runs AS a subagent at that point.

\*\*\*\*\* Multiple hooks matching the same event execute concurrently. This is not parallel workstreams like Agent Teams.

## Anti-Patterns and Redirects

### "I want CLAUDE.md for..."

**Redirect to Rules if:**

- It's a focused concern that should be modular (testing rules, API conventions, security)
- You want to organize instructions into maintainable files
- It applies to specific file paths only

**Redirect to Skill if:**

- It's extensive documentation that shouldn't always load
- It's task-specific knowledge, not universal conventions
- It would push CLAUDE.md over ~60 lines

**Redirect to Hook if:**

- It's enforceable by a linter, script, or automated check
- It should run automatically on lifecycle events
- It's validation that doesn't need to be in context

**Redirect to @import files if:**

- It's universal context but too long for CLAUDE.md
- It's reference material that should be available but not always in context

### "I want Agent Teams for..."

**Redirect to Subagent if:**

- Task doesn't benefit from parallelism (sequential dependencies)
- You wouldn't assign this to multiple humans simultaneously
- Single-threaded execution is fast enough
- Token budget is a concern (teams use ~Nx tokens for N teammates)

**Redirect to Skill if:**

- It's knowledge/guidelines, not active work
- Same context is fine; no isolation needed
- No tool restrictions required

### "I want a Subagent for..."

**Redirect to Skill if:**

- It doesn't need isolated context
- It doesn't need tool restrictions
- It's reference information, not a task executor

**Redirect to Hook if:**

- It's deterministic (no judgment needed)
- It should run automatically on events
- It's validation/formatting/notification

### "I want a Skill for..."

**Redirect to CLAUDE.md/Rules if:**

- It should always be loaded, not triggered by relevance
- It's project-wide conventions, not task-specific knowledge

**Add `disable-model-invocation: true` if:**

- It has side effects (deploys, PRs, mutations)
- User should explicitly invoke it, not auto-trigger

### "I want a Hook for..."

**Redirect to Skill/Subagent if:**

- It requires complex reasoning beyond a single prompt
- It needs conversation context
- It's not tied to a specific lifecycle event

### "I want Rules for..."

**Redirect to Skill if:**

- It's extensive documentation that shouldn't always load
- It's task-specific, not universally applicable

**Redirect to Hook if:**

- It's enforceable by a linter or script
- It should run automatically, not as guidance

## Decision Tree Summary

```txt
START
│
├─ Should this always be in context?
│  ├─ Yes → Is it short (<60 lines)?
│  │         ├─ Yes → Is it focused/modular (testing, security, API)?
│  │         │         ├─ Yes → Rules file
│  │         │         └─ No (cross-cutting: stack, commands) → CLAUDE.md
│  │         └─ No → Is it focused/modular (testing, security, API)?
│  │                   ├─ Yes → Rules file
│  │                   └─ No (cross-cutting) → CLAUDE.md with @import references
│  │
│  └─ No → Does it need to run automatically on events?
│           ├─ Yes → Hook
│           └─ No → Does it need its own context?
│                    ├─ Yes → Do you need parallelism?
│                    │         ├─ Yes → Agent Team
│                    │         └─ No → Subagent
│                    └─ No → Should user explicitly invoke it?
│                             ├─ Yes (side effects) → Skill (manual)
│                             └─ No (auto-trigger) → Skill
```

## Confirming the Choice

Before proceeding to authoring, confirm with the user:

1. State which feature you recommend
2. Explain why based on their answers
3. If they originally asked for a different feature, explain the tradeoff
4. Get explicit confirmation before proceeding

Example: "Based on your answers, this should be a **Skill** rather than a Subagent. You don't need isolated context or tool restrictions — you just want Claude to have this knowledge when relevant. A Skill has zero context cost until triggered, while a Subagent adds coordination overhead. Does that make sense, or is there a reason you need isolation?"
