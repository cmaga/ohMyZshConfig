# Project Brief: cline-docs Skill

## Purpose

The cline-docs skill is a knowledge base that provides targeted context for answering questions about Cline, the AI coding assistant.

## Design Philosophy

Rather than loading entire documentation, the skill routes questions to specific doc files based on topic. This keeps context efficient and responses focused.

## Scope

The knowledge base covers:

| Topic           | Description                                                                                          |
| --------------- | ---------------------------------------------------------------------------------------------------- |
| Architecture    | Extension internals, WebviewProvider, Controller, Task, state management, gRPC/protobuf              |
| Core Workflows  | Checkpoints, Plan/Act mode, task management, file operations, @-mentions, slash commands             |
| Customization   | Cline rules, skills, workflows, hooks, .clineignore                                                  |
| Features        | Memory bank, focus chain, auto-approve, subagents, auto-compact, background edit, Jupyter, worktrees |
| MCP             | MCP servers, marketplace, server development, transport mechanisms                                   |
| Providers       | API provider configuration (Anthropic, OpenAI, Bedrock, etc.)                                        |
| CLI             | Terminal mode, headless mode, ACP, CLI configuration                                                 |
| Troubleshooting | Terminal issues, networking, proxies, task history recovery                                          |
| Tools           | Tool reference, browser automation, available tools                                                  |

## Success Criteria

1. Questions are routed to the correct documentation file
2. Documentation is concise and actionable
3. Cross-references connect related concepts
4. Updates are traceable to source files in the Cline repository

## Source

All documentation is synthesized from the Cline repository:

- `.clinerules/` files for architecture and internal patterns
- `docs/*.mdx` files for user-facing documentation
