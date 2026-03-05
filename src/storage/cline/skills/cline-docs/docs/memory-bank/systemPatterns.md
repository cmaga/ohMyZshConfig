# System Patterns: cline-docs Skill

## Topic-to-Doc Routing Pattern

The core pattern of this skill is routing questions to specific documentation files rather than loading everything at once.

```
User Question → SKILL.md Routing Table → Specific Doc File → Focused Answer
```

This pattern:

- Minimizes context window usage
- Provides focused, relevant information
- Scales well as documentation grows

## Writing Conventions

These conventions optimize documentation for Claude's comprehension:

### Structure Pattern

1. **Mental model first**: Brief statement of what the concept IS and its purpose
2. **Core patterns**: The 80% case, the happy path
3. **Edge cases**: Exceptions, gotchas, special handling
4. **Cross-references**: Links to related concepts in other docs

### Format Preferences

| Format       | Use For                                         |
| ------------ | ----------------------------------------------- |
| Tables       | Comparisons, option lists, parameter references |
| Code blocks  | Commands, file paths, configuration examples    |
| Bullet lists | Sequential steps, feature lists                 |
| Headers      | Scannable anchors for quick navigation          |

### Content Rules

**Keep:**

- Actionable information (how to do X)
- Configuration patterns and examples
- Error conditions and fixes
- Relationships between concepts
- File paths and directory structures

**Remove:**

- Marketing language
- Redundant explanations
- Overly verbose examples
- Screenshots (describe if important)

## Quick Reference Tables

Each doc file may include quick reference tables for common lookups:

- Key directories and their purposes
- Configuration file locations
- Common commands
- Mode differences

## Cross-Reference Pattern

When concepts span multiple docs, use explicit cross-references:

```markdown
See [related concept](other-doc.md#section) for details on X.
```

## Update Traceability Pattern

Every doc maps to specific source files in the Cline repository. This allows:

- Tracking when updates are needed
- Verifying accuracy against source
- Understanding where information came from

The mapping is documented in `scripts/dev-notes.md`.
