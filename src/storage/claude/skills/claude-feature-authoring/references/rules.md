# Rules File Authoring Guide

Rules files (`.claude/rules/*.md`) are auto-loaded alongside CLAUDE.md with the same priority. They decompose always-on instructions into focused, maintainable units.

## Location

```txt
.claude/
└── rules/
    ├── testing.md
    ├── api-conventions.md
    ├── security.md
    └── frontend/
        └── components.md
```

Rules files are discovered recursively — subdirectories like `frontend/` work for organization.

**Project rules:** `.claude/rules/` — committed to repo, shared with team

**User rules:** `~/.claude/rules/` — personal rules applied to all projects (lower priority than project rules)

## Loading Behavior

- **Without frontmatter:** Always loaded at session start
- **With `paths` frontmatter:** Conditionally loaded when Claude works on matching files

Path-scoped behavior may vary across versions. If a rule doesn't seem to activate correctly, verify which rules loaded.

## Writing Rules Files

Each file should focus on one concern. Keep files short — they're always in context (unless path-scoped).

### Example: testing.md

```md
# Testing Rules

- Every new component requires a co-located `.test.tsx` file
- Use React Testing Library, not Enzyme
- Test behavior, not implementation: query by role/text, not class/id
- Run `pnpm test -- --related` before committing to check affected tests
- Integration tests go in `tests/integration/`, not alongside components
```

### Example: security.md

```md
# Security Rules

- Never log or print secrets, tokens, or API keys
- Use environment variables for all credentials — never hardcode
- Sanitize all user input before database queries
- Use parameterized queries exclusively — no string concatenation for SQL
```

## Path-Scoped Rules

Use YAML frontmatter with the `paths` field to make rules conditional:

```md
---
paths:
  - "src/api/**/*.ts"
  - "src/services/**/*.ts"
---

# API Rules

- All endpoints must validate input with zod schemas
- Return consistent error response format: `{ error: string, code: number }`
- Log request IDs for traceability
```

The rule only activates when Claude reads or writes files matching the glob patterns.

**When to use path scoping:**

- Framework-specific rules (React components vs Node services)
- Rules that conflict between parts of the codebase
- Expensive context you don't want loaded for unrelated tasks

## Guidelines

- **One concern per file**: Don't mix testing rules with API conventions
- **Brevity**: Every line is always in context. Cut anything Claude already does correctly
- **Imperative voice**: "Use parameterized queries" not "You should consider using parameterized queries"
- **Verifiable**: Prefer rules that can be checked ("Run `pnpm lint` to verify") over subjective guidance
- **No duplication**: If a rule is already in CLAUDE.md or enforced by a linter, don't repeat it here

## Managed Policies

In Team/Enterprise contexts, managed policy CLAUDE.md files cannot be excluded via settings — use managed policies for organization-wide rules that must always apply.
