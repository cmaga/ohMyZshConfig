# Subagent Authoring Guide

Subagents are specialized AI assistants that run in their own context window. Use them for tasks that need isolation, focused tool access, or would bloat the main session.

## Quick Start

**Recommended**: Use `/agents` for interactive creation, editing, and management.

**Manual creation**: Add a file to one of:

- Project-level: `.claude/agents/<name>.md` (scoped to repo)
- User-level: `~/.claude/agents/<name>.md` (available across all projects)

If you create a file manually, restart your session or run `/agents` to load it immediately.

## Naming Convention

Agent filenames and `name` fields must end in `-agent` (e.g., `code-review-agent`, `security-expert-agent`). This removes ambiguity when referencing agents in skills, orchestration flows, and `@` mentions.

## Format

Markdown file with YAML frontmatter. The markdown body becomes the subagent's system prompt, replacing the default Claude Code system prompt entirely. CLAUDE.md files and project memory still load through the normal message flow.

```yaml
---
name: code-review-agent
description: Reviews code for quality, readability, and best practices
tools: Read, Grep, Glob
model: sonnet
memory: project
---

You are a code reviewer. Analyze code for:
1. Correctness and edge cases
2. Readability and naming
3. Performance concerns
4. Adherence to project conventions

Present findings as a prioritized list with file:line references.
```

## Frontmatter Reference

| Field             | Values                                           | Default   | Purpose                                               |
| ----------------- | ------------------------------------------------ | --------- | ----------------------------------------------------- |
| `name`            | string                                           | —         | Identifier, appears as `@<name>` in UI                |
| `description`     | string                                           | —         | When Claude should delegate to this agent             |
| `tools`           | comma-separated                                  | all       | Restricts available tools (omit to inherit all)       |
| `disallowedTools` | comma-separated                                  | none      | Deny list — inverse of `tools`                        |
| `model`           | `sonnet`, `opus`, `haiku`, `inherit`                                     | `inherit` | Prefer aliases — they auto-resolve to the latest version              |
| `memory`          | `user`, `project`, `local`, or omit              | none      | Persistent learning across sessions                   |
| `maxTurns`        | number                                           | —         | Limit agentic loop iterations                         |
| `skills`          | list of skill names                              | —         | Skills preloaded at startup (full content injected)   |
| `permissionMode`  | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan` | — | Controls permission prompt handling |
| `mcpServers`      | list of MCP server names                         | —         | MCP servers the subagent can access                   |
| `effort`          | `low`, `medium`, `high`, `xhigh`, `max`          | —         | Override session reasoning effort (model-dependent)   |
| `background`      | boolean                                          | `false`   | Run concurrently without blocking                     |
| `isolation`       | `worktree`                                       | —         | Run subagent in isolated git worktree                 |
| `hooks`           | object                                           | —         | Lifecycle hooks scoped to subagent                    |

**Plugin subagents** do not support `hooks`, `mcpServers`, or `permissionMode` — these fields are silently ignored.

## Tool Access

By default, subagents inherit all tools from the main conversation, including MCP tools. Use `tools` to restrict or `disallowedTools` to deny specific tools.

```yaml
# Read-only explorer (explicit allowlist)
tools: Read, Grep, Glob

# Full access except writing (deny list)
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit

# Inherit everything (omit tools field entirely)
```

For finer control, use `PreToolUse` hooks to validate operations:

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly.sh"
```

## Memory

Memory lets subagents accumulate knowledge across sessions. First 200 lines of `MEMORY.md` are injected into the subagent's system prompt, and Read/Write/Edit tools are auto-enabled for memory management.

| Scope     | Path                                       | Use case                          |
| --------- | ------------------------------------------ | --------------------------------- |
| `project` | `.claude/agent-memory/<agent-name>/`       | Shared via version control        |
| `user`    | `~/.claude/agent-memory/<agent-name>/`     | Personal, applies across projects |
| `local`   | `.claude/agent-memory-local/<agent-name>/` | Not checked into version control  |

`project` is the recommended default scope.

The subagent receives instructions to curate `MEMORY.md` if it exceeds 200 lines. It can also create topic-specific files beyond `MEMORY.md` for organized knowledge.

```yaml
---
name: db-expert
description: Database query optimization and schema analysis
memory: project
---
You are a database expert. As you analyze queries and schemas, update your
agent memory with discovered patterns, table relationships, and optimization
insights.
```

## Execution Modes

### Foreground (default)

Blocks the main conversation. Permission prompts pass through to the user.

### Background

Runs concurrently. No user interaction possible during execution.

Before launching a background subagent, Claude Code asks for tool permissions upfront. Once running, the subagent inherits those permissions and automatically refuses anything not pre-approved.

```yaml
---
name: background-indexer
background: true
---
```

### As Default Agent

Launch Claude Code with a subagent as the main session:

```bash
claude --agent code-review-agent
```

Or set as project default in `.claude/settings.json`:

```json
{ "agent": "code-review-agent" }
```

**This is fundamentally different from delegation.** When run via `--agent`, the subagent's system prompt replaces the default Claude Code system prompt entirely — the subagent IS the main session, not a delegated task.

## Resolution and Permissions

### Name Conflict Priority

When multiple subagents share the same name:

1. `--agents` CLI flag (highest)
2. `.claude/agents/` (project)
3. `~/.claude/agents/` (user)
4. Plugin agents (lowest)

### Denying Subagents

Block specific subagents with `Agent(subagent-name)` in the `deny` array in settings or via `--disallowedTools`.

## Hooks in Subagents

Hooks defined in subagent frontmatter are scoped to the subagent's lifecycle. `Stop` hooks automatically convert to `SubagentStop`:

```yaml
---
name: safe-deployer
description: Handles deployment with safety checks
hooks:
  Stop:
    - hooks:
        - type: agent
          prompt: "Verify all tests pass before completing."
          timeout: 120
---
```

## Lightweight Alternative

For a quick question about something already in your conversation, use `/btw` instead of a subagent. It sees your full context but has no tool access, and the response is discarded.
