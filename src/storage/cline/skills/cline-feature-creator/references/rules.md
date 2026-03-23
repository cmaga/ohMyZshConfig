# Creating Rules

Rules are markdown files with persistent instructions that apply across conversations.

## When to Use

- Behavioral guidance that should always (or conditionally) apply
- Short, focused constraints (under 60 lines for root-level)
- Coding conventions, naming standards, project-specific restrictions

## Storage Locations

| Scope   | Location                   | Notes                               |
| ------- | -------------------------- | ----------------------------------- |
| Global  | `~/Documents/Cline/Rules/` | Applies to all projects             |
| Project | `.clinerules/`             | Committed to repo, shared with team |

## Anatomy

### Basic Rule

```markdown
# Rule Title

## Category

- Specific instruction
- Example: `like this`
- Reference: see /src/utils/example.ts
```

### Conditional Rule (Path-Scoped)

Add YAML frontmatter to activate only when working with matching files:

```yaml
---
paths:
  - "src/components/**"
  - "**/*.test.ts"
---
# React Component Guidelines

- Use functional components with hooks
- Export components as named exports
- Place tests adjacent to components
```

#### Glob Patterns

- `*` — any characters except `/`
- `**` — any characters including `/` (recursive)
- `{a,b}` — match either pattern

#### Context Sources for Matching

- File paths mentioned in prompt
- Open tabs in the editor
- Visible editor panes
- Files edited during the current task

## Best Practices

- Be specific: "Use camelCase for variables" over "Use good names"
- Include the why: "Do not modify /legacy (scheduled for removal Q2)"
- Point to examples: "Follow pattern in /src/utils/errors.ts"
- One concern per file
- Keep concise — rules consume context tokens on every task

## Common Patterns

### Technology Constraints

```markdown
# TypeScript Only

- Write all new files as `.ts` or `.tsx`
- Import types with `import type { }` syntax
```

### Directory Protection

```markdown
# Protected Directories

- Do not modify files in `src/generated/` — these are auto-generated
- Do not modify `.cline-project/workflows/memory-bank/` — user-maintained docs
```

### Code Style

```markdown
# Code Style

- Use early returns to reduce nesting
- Name boolean variables with `is`/`has`/`should` prefix
- Prefer `const` over `let`
```

## Verification

After creating a rule, verify:

1. File is saved to the correct location
2. If conditional, glob patterns match intended files: test with `ls src/components/**/*.tsx`
3. Rule is under 60 lines (root-level) or under 200 lines (deep files)
4. No compound instructions — one point per bullet
