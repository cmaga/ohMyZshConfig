# Technical Context: cline-docs Skill

## Project Structure

```
cline-docs/
├── SKILL.md              # Entry point with routing table
├── docs/
│   ├── architecture.md   # Extension internals
│   ├── cli.md            # CLI and terminal mode
│   ├── core-workflows.md # Checkpoints, Plan/Act, tasks
│   ├── customization.md  # Rules, skills, hooks
│   ├── features.md       # Memory bank, subagents, etc.
│   ├── mcp.md            # MCP servers
│   ├── providers.md      # API provider configuration
│   ├── tools.md          # Tool reference
│   ├── troubleshooting.md# Common issues and fixes
│   └── memory-bank/      # This directory
└── scripts/
    └── dev-notes.md      # Build and update procedures
```

## Source File Mapping

Documentation is synthesized from the Cline repository:

| Doc File           | Primary Sources                 | Secondary Sources                                                                         |
| ------------------ | ------------------------------- | ----------------------------------------------------------------------------------------- |
| architecture.md    | `.clinerules/cline-overview.md` | `.clinerules/general.md`, `.clinerules/protobuf-development.md`, `.clinerules/storage.md` |
| core-workflows.md  | `docs/core-workflows/*.mdx`     | -                                                                                         |
| customization.md   | `docs/customization/*.mdx`      | -                                                                                         |
| features.md        | `docs/features/*.mdx`           | -                                                                                         |
| mcp.md             | `docs/mcp/*.mdx`                | -                                                                                         |
| providers.md       | `docs/provider-config/*.mdx`    | `.clinerules/general.md` (Adding API Provider section)                                    |
| cli.md             | `docs/cline-cli/*.mdx`          | `.clinerules/cli.md`                                                                      |
| troubleshooting.md | `docs/troubleshooting/*.mdx`    | -                                                                                         |
| tools.md           | `docs/tools-reference/*.mdx`    | -                                                                                         |

## Integration with Cline Skills System

### Skill Location

This skill lives in `~/.cline/skills/cline-docs/` as a global skill available to all projects.

### Activation

The skill activates when:

1. User asks about Cline features, configuration, or troubleshooting
2. Agent matches the question to the skill description in SKILL.md
3. Agent uses `use_skill` tool with `skill_name: "cline-docs"`

### Context Loading

After activation:

1. SKILL.md content is loaded into context
2. Agent reads routing table to identify relevant doc
3. Agent uses `read_file` to load the specific doc file
4. Answer is generated from loaded context

## Dependencies

- No external dependencies
- Pure markdown documentation
- Requires Cline skills system to be enabled

## Key Files for Updates

When Cline documentation changes:

1. Check `scripts/dev-notes.md` for update procedure
2. Identify which source files changed
3. Update corresponding doc file
4. Update version history in dev-notes.md
