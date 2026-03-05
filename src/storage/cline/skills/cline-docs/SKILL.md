---
name: cline-docs
description: Answer questions about Cline - the AI coding assistant. Use when asked about Cline features, workflows, configuration, architecture, MCP servers, CLI usage, providers, or troubleshooting. This is the Cline knowledge base. Or asked to reference the cline documentation.
---

# Cline Knowledge Base

This skill provides targeted documentation for answering questions about Cline.

## Routing

Based on the question, read the relevant doc file:

| Question Topic | Doc to Read |
|----------------|-------------|
| How Cline works internally, extension architecture, WebviewProvider, Controller, Task, state management, gRPC/protobuf, adding tools, modifying system prompt | [docs/architecture.md](docs/architecture.md) |
| Checkpoints, Plan/Act mode, task management, working with files, @-mentions, slash commands | [docs/core-workflows.md](docs/core-workflows.md) |
| Cline rules, skills, workflows, hooks, .clineignore | [docs/customization.md](docs/customization.md) |
| Memory bank, focus chain, auto-approve, subagents, auto-compact, background edit, Jupyter notebooks, worktrees | [docs/features.md](docs/features.md) |
| MCP servers, MCP marketplace, adding servers, server development, transport mechanisms | [docs/mcp.md](docs/mcp.md) |
| API providers, configuring Anthropic/OpenAI/Bedrock/etc., adding new providers | [docs/providers.md](docs/providers.md) |
| Cline CLI, terminal mode, headless mode, ACP, CLI configuration | [docs/cli.md](docs/cli.md) |
| Terminal issues, networking, proxies, task history recovery | [docs/troubleshooting.md](docs/troubleshooting.md) |
| Tool reference, browser automation, all available tools | [docs/tools.md](docs/tools.md) |

## Quick Reference

### Key Directories

```
src/core/controller/     # Message handling, state management
src/core/task/           # Task execution, tool handling
src/core/prompts/        # System prompt variants
src/api/providers/       # API provider implementations
webview-ui/              # React frontend
cli/                     # Terminal UI (React Ink)
docs/                    # User documentation
.clinerules/             # Project-specific rules
```

### Common Configuration Locations

| What | Where |
|------|-------|
| Global rules | `~/.cline/rules/` |
| Project rules | `.clinerules/` or `.cline/rules/` |
| Global skills | `~/.cline/skills/` |
| Project skills | `.cline/skills/` |
| MCP settings | `~/.cline/mcp_settings.json` |
| Global state | `~/.cline/data/globalState.json` |
| Secrets | `~/.cline/data/secrets.json` |

### Mode Toggle

- **Plan Mode**: Information gathering, discussion, creating plans. Uses `plan_mode_respond` tool.
- **Act Mode**: Executing tasks, using tools, making changes. All tools except `plan_mode_respond`.

User manually toggles between modes. Suggest "toggle to Act mode" when ready to implement.