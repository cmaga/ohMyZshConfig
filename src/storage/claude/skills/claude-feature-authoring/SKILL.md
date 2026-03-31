---
name: claude-feature-authoring
description: |
  Guidelines for writing markdown files consumed by LLMs as instructions — CLAUDE.md, SKILL.md, subagent definitions, hooks, rules, and workflow commands. Use when creating, revising, or reviewing any context-injection file for Claude Code, or similar agentic coding tools. Also use when the user mentions CLAUDE.md, SKILL.md, AGENTS.md, .claude, or asks how to structure instructions for an AI coding assistant.
disable-model-invocation: true
---

# Claude Feature Authoring

You are helping author markdown files consumed by Claude as instructions. Every token competes with system prompts, conversation history, and code context.

## Phase 1: Understand Intent

Before selecting a feature type, understand what the user is trying to solve.

1. Ask what problem they're trying to automate or what behavior they want from Claude
2. Ask what triggers this — always, on specific events, on demand, or by relevance?
3. Clarify scope — project-specific or across all projects?

Do not assume a feature type yet. Gather enough context to make an informed recommendation. During this phase, respond with how you rate your own understanding of the user's intent. Do not proceed to phase 2 until your confidence is 10/10.

## Phase 2: Feature Selection

Given the understood intent, determine the right feature type. Read [references/feature-selection.md](references/feature-selection.md) and walk through the decision process.

Users often start with a feature in mind that isn't optimal for their use case. The feature selection guide will map their answers to the appropriate feature and redirect if they've chosen the wrong tool.

## Phase 3: Check Existing Capabilities

Before creating anything new, check if the problem is already solved.

1. Run `/skills` to list installed skills
2. Check existing project files (CLAUDE.md, `.claude/rules/`, `.claude/hooks/`) for overlapping guidance

If an existing feature covers the use case, tell the user it exists and how to invoke it. If it's close but needs improvement, recommend improving it rather than building from scratch.

## Present Plan Before Writing

Summarize your findings before authoring anything and wait for user approval:

1. What the user wants (from Phase 1)
2. The recommended feature type and why (from Phase 2)
3. Whether creating new or improving existing (from Phase 3)

## Phase 4: Authoring

Once the user confirmed what they want, apply universal authoring rules and type-specific guidelines. Each feature type has its own reference file with best practices, templates, and anti-patterns.

### Universal Authoring Rules

These apply to every context-injection file regardless of type.

#### Token Economy

- Claude is already smart. Only add context it cannot infer from code
- If removing a line wouldn't cause mistakes, delete it
- Frontier models follow ~150-200 instructions before uniform degradation
- Claude Code's system prompt burns ~50 instructions already

#### Writing Style

- One instruction per bullet
- Imperative voice, no hedging ("try to", "consider", "you might want to")
- Positive framing over negative ("Use X exclusively" not "Don't use Y")
- Examples over explanations
- File pointers over inlined content
- Reserve CAPS/bold for max 1-2 truly critical rules
- No nested bullets deeper than 2 levels

#### Attention Model

- Attention biases toward periphery (top + bottom of file)
- Middle of the file gets least attention
- For files >100 lines, repeat critical rules at the bottom

#### Structure Template

```md
# [Purpose - one line]

## Critical Rules

[1-3 non-negotiable constraints. Top of file = highest attention]

## Context

[Stack, structure, key patterns. File pointers to deeper docs]

## Workflow

[Numbered if sequential, bullets if not]

## Verification

[Exact commands to validate work]
```

#### Anti-Patterns

- **Kitchen sink**: stuffing every instruction degrades all instruction-following uniformly
- **Stale snippets**: pasted code that drifts from codebase — use file refs or scripts
- **Style guides as instructions**: belong in linter configs and hooks
- **Redundant instructions**: if Claude does it correctly unprompted, delete it
- **Deep reference chains**: A → B → C → actual info — keep one level deep

#### Self-Check Before Finalizing

1. Is guidance focused on the what instead of the how?
2. Can deterministic tasks use a script instead of instructions?
3. Is this already default LLM behavior? Remove
4. Duplicates another instruction? Consolidate
5. Would this work with Haiku, not just Opus?

### Type-Specific Reference Files

After feature selection, read the relevant reference:

| Feature         | Reference                                                          |
| --------------- | ------------------------------------------------------------------ |
| CLAUDE.md       | [references/claude-entrypoint.md](references/claude-entrypoint.md) |
| Rules           | [references/rules.md](references/rules.md)                         |
| Skill/Workflows | [references/skills.md](references/skills.md)                       |
| Subagent        | [references/subagents.md](references/subagents.md)                 |
| Agent team      | [references/agent-teams.md](references/agent-teams.md)             |
| Hook            | [references/hooks.md](references/hooks.md)                         |
