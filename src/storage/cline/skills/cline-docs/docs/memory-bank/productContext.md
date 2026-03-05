# Product Context: cline-docs Skill

## Why This Skill Exists

AI agents need efficient access to Cline documentation when answering user questions. Loading all documentation at once wastes context window space. This skill solves that by providing a routing system that loads only the relevant doc file for each question topic.

## Target Users

The primary user is the AI agent (Claude) operating within Cline. When a user asks about Cline features, the agent activates this skill to get accurate, targeted information.

## How It Works

1. User asks a Cline-related question
2. Agent activates the cline-docs skill
3. SKILL.md provides a routing table mapping topics to doc files
4. Agent reads the relevant doc file(s)
5. Agent answers using the loaded context

## Routing System

The SKILL.md file contains a routing table:

| Question Topic                              | Doc File           |
| ------------------------------------------- | ------------------ |
| Internal architecture, extension design     | architecture.md    |
| Checkpoints, Plan/Act mode, task management | core-workflows.md  |
| Rules, skills, workflows, hooks             | customization.md   |
| Memory bank, auto-approve, subagents        | features.md        |
| MCP servers, marketplace                    | mcp.md             |
| API providers, configuration                | providers.md       |
| CLI, terminal mode, headless                | cli.md             |
| Terminal issues, networking                 | troubleshooting.md |
| Tool reference, browser automation          | tools.md           |

## User Experience Goals

1. **Fast answers**: Route to correct doc immediately
2. **Accurate information**: Documentation synthesized from authoritative sources
3. **Consistent format**: All docs follow the same conventions for predictable parsing
4. **Maintainable**: Clear update procedure when Cline changes

## Relationship to Cline

This skill is part of Cline's global skills directory (`~/.cline/skills/`). It acts as Cline's self-documentation - the agent can learn about itself by activating this skill.
