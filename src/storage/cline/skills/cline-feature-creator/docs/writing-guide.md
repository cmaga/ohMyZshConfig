# Writing Guide for LLM Instructions

Every token in a context injection file competes with system prompts, conversation history, and code context. Write lean, high-signal instructions.

## Key Facts

- Frontier thinking models follow ~150-200 instructions before uniform degradation
- Cline's system prompt consumes ~50 instructions already
- Attention biases toward the top and bottom of a file — the middle gets least attention
- As instruction count increases, ALL instructions degrade uniformly, not just new ones

## Rules

- Target <200 lines for any single file. <60 for root-level files (.clinerules)
- One instruction per bullet — no compound sentences
- Imperative voice, no hedging ("try to", "consider", "you might want to")
- Positive framing: "Use X exclusively" instead of "Don't use Y"
- Examples over explanations — a single code block replaces a paragraph
- File pointers over inlined content — never paste code that will go stale
- Reserve CAPS/bold for 1-2 truly critical rules maximum. Overuse dilutes everything
- Include verification steps with exact commands
- Use `##` headings as section anchors — strong attention signal in long prompts
- No nested bullets deeper than 2 levels

## Structure Template

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
```

If the file exceeds ~100 lines, repeat critical rules at the bottom.

## Skill-Specific Guidance

### Description Field

The `description` in SKILL.md frontmatter is the primary trigger mechanism. Make it slightly "pushy" — Cline tends to under-trigger skills.

Instead of: "How to build dashboards"
Write: "How to build dashboards. Use this skill whenever the user mentions dashboards, data visualization, internal metrics, or wants to display any kind of data, even if they don't explicitly ask for a 'dashboard.'"

### Progressive Disclosure

Keep SKILL.md under 500 lines. If approaching this limit:

- Move reference material to `docs/` or `references/` subdirectories
- Add clear pointers with conditions: "Read `docs/api.md` when working with the REST API"
- For large reference files (>300 lines), include a table of contents

### Examples Pattern

```md
## Commit message format

**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Output Format Pattern

```md
## Report structure

ALWAYS use this exact template:

# [Title]

## Executive summary

## Key findings

## Recommendations
```

## Anti-Patterns

| Anti-Pattern                 | Why It Fails                                                           | Fix                                                                       |
| ---------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Kitchen sink                 | Stuffing every possible instruction degrades all instruction-following | Cut ruthlessly. If Claude does it correctly without being told, delete it |
| Stale snippets               | Pasted code drifts from the codebase                                   | Use file refs: `See src/utils/errors.ts`                                  |
| Style guides as instructions | These belong in linter configs, not LLM prompts                        | Move to linter/formatter config                                           |
| Redundant instructions       | Wastes tokens on default LLM behavior                                  | Remove anything Claude already does well                                  |
| Heavy-handed MUSTs           | Overuse of ALWAYS/NEVER/MUST dilutes all emphasis                      | Explain the why instead — LLMs respond better to reasoning                |

## Self-Check

Before finalizing any LLM instruction file, verify:

1. Is guidance focused on the **what** instead of the **how**?
2. Can any deterministic task be handled by a script instead of instructions?
3. Is this already default LLM behavior? If so, remove it
4. Does it duplicate another instruction? Consolidate
5. Would a single example replace a paragraph of explanation? Use the example
