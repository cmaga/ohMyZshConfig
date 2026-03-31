# CLAUDE.md Authoring Guide

Only include what Claude cannot infer from code. CLAUDE.md competes for context with code, conversation, and system prompts.

CLAUDE.md is re-injected into context at session start and after `/compact`. Conversational instructions are summarized lossy during compaction — CLAUDE.md is re-read verbatim from disk.

## Line Targets

- Root CLAUDE.md: <60 lines
- Child files: keep short — adherence degrades past ~200 lines total loaded context

## Content: What Belongs Here

CLAUDE.md answers three questions: What is this project? How do I work in it? What must I never do?

```md
# Project Name

## Stack

TypeScript, Next.js 15, pnpm, Tailwind, Drizzle ORM

## Commands

- Build: `pnpm build`
- Test: `pnpm test -- --watch` # `--` passes args through pnpm to test runner
- Lint: `pnpm lint`
- Single test: `pnpm test -- path/to/file.test.ts`

## Conventions

Functional React components with server components by default.
Import paths use `@/` alias. No barrel exports.
New API routes require a corresponding integration test.
```

## What Does NOT Belong

- Style rules enforceable by linters → put in linter config + a hook
- Task-specific workflows → put in a Skill
- Information that changes per-task → put in a Skill or subagent
- Detailed API docs → put in a referenced file via `@import`
- Anything Claude already does correctly without being told

## Hierarchy and Loading

```
repo/
├── CLAUDE.md                    # Always loaded
├── packages/
│   └── api/
│       └── CLAUDE.md            # Loaded on demand when working in api/
└── .claude/
    └── rules/
        └── testing.md           # Auto-loaded alongside root CLAUDE.md
```

- **Root CLAUDE.md**: Always in context
- **Child directory CLAUDE.md**: Loaded on demand when Claude works in that directory
- **`.claude/rules/*.md`**: Auto-loaded alongside CLAUDE.md, same priority — use for team-wide rules that apply universally
- **`@path/to/file.md`**: Inline import syntax, supports nested imports
- **User-level**: `~/.claude/CLAUDE.md` — loaded for all projects

For command allowlists and permissions, see `.claude/settings.json` (team) and `.claude/settings.local.json` (personal).

## Progressive Disclosure

Keep root CLAUDE.md lean. Push detailed docs into child files or `@imports`:

```md
## API Conventions

@docs/api-conventions.md

## Database Patterns

@docs/database-patterns.md
```

Claude reads imported files on demand. This keeps root context small while making deep knowledge accessible.
