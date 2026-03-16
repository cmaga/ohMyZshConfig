# Workflow: AI Markdown Authoring

You are writing or revising a markdown file that will be consumed by an LLM (Claude) as instructions. This is a context injection file, NOT documentation. Every token competes with system prompts, conversation history, and code context.

## Key Facts

- Frontier thinking models follow ~150-200 instructions before uniform degradation
- Claude Code's system prompt burns ~50 instructions already
- Attention biases toward the periphery (top + bottom of file). Middle gets least attention
- As instruction count increases, ALL instructions degrade uniformly — not just the new ones

## Rules

- Target <200 lines. <60 for root-level files (CLAUDE.md, .clinerules)
- One instruction per bullet — no compound sentences
- Imperative voice, no hedging ("try to", "consider", "you might want to")
- Positive framing over negative ("Use X exclusively" not "Don't use Y")
- Examples over explanations — a single code block replaces a paragraph
- File pointers over inlined content — never paste code that will go stale. Use `path/to/file.md — Read when [condition]`
- Reserve CAPS/bold for max 1-2 truly critical rules. Overuse dilutes all of them
- Include verification steps (exact commands to validate work)
- `##` headings as section anchors — strong attention signal, especially in long prompts
- XML tags (`<constraints>`, `<output_format>`) only when you need hard data/instruction boundaries
- No nested bullets deeper than 2 levels

## Structure

```md
# [Purpose — one line]

## Critical Rules

[1-3 non-negotiable constraints. Top of file = highest attention]

## Context

[Stack, structure, key patterns. File pointers to deeper docs]

## Workflow

[Numbered if sequential, bullets if not]

## Verification

[Exact commands to validate work]

## [Repeat critical rules if file exceeds ~100 lines]
```

## Anti-Patterns

- Kitchen sink: stuffing every possible instruction. Degrades all instruction-following
- Stale snippets: pasted code that drifts from the codebase. Use file refs
- Style guides as instructions: these belong in linter configs
- Redundant instructions: if Claude does it correctly without being told, delete it

## Self-Check Before Finalizing

For each task ask:

1. Is guidance focused on the what instead of the how?
2. can we save tokens on any deterministic tasks by using a script?
3. Is this already default LLM behavior?
4. Duplicates another instruction? Yes → consolidate
