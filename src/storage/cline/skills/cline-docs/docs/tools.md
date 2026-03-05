# Cline Tools Reference

## Overview

Cline has built-in tools for file operations, terminal commands, browser automation, and MCP integrations.

## File Operations

| Tool | Description |
|------|-------------|
| `write_to_file` | Create or overwrite files |
| `read_file` | Read file contents |
| `replace_in_file` | Make targeted edits with SEARCH/REPLACE blocks |
| `search_files` | Search files using regex |
| `list_files` | List directory contents |
| `list_code_definition_names` | List code definitions (classes, functions) |

### replace_in_file Syntax

```
------- SEARCH
[exact content to find]
=======
[new content to replace with]
+++++++ REPLACE
```

Multiple SEARCH/REPLACE blocks can be used in one call. List them in file order.

## Terminal Operations

| Tool | Description |
|------|-------------|
| `execute_command` | Run CLI commands |

The `requires_approval` parameter:
- `true` - Potentially impactful (install packages, delete files, network ops)
- `false` - Safe operations (read files, build, run dev server)

## Browser Operations

| Tool | Description |
|------|-------------|
| `browser_action` | Interact with websites via Puppeteer |

Actions: `launch`, `click`, `type`, `scroll_down`, `scroll_up`, `close`

Browser runs at fixed 900x600 resolution.

## MCP Tools

| Tool | Description |
|------|-------------|
| `use_mcp_tool` | Execute MCP server tools |
| `access_mcp_resource` | Access MCP server resources |

## Interaction Tools

| Tool | Description |
|------|-------------|
| `ask_followup_question` | Ask user for clarification |
| `attempt_completion` | Present final results |

## New Task Tool

Creates a fresh task with distilled context from current conversation.

### When to Use

- Context window filling up but work isn't done
- Completing a logical subtask before starting next
- After research phase, ready to implement

### /newtask Command

Type `/newtask` in chat. Cline will:
- Analyze conversation
- Propose distilled context
- Let you refine before creating new task

## Tool Execution Flow

```
User request → Cline parses → Tool call → User approval → Execute → Result
```

For each tool call:
1. Cline determines appropriate tool
2. Presents action for approval (unless auto-approved)
3. Executes tool
4. Creates checkpoint (for file operations)
5. Returns result

## Cross-References

- MCP tools → See [mcp.md](mcp.md)
- Auto-approve settings → See [features.md](features.md)
- Checkpoints after tool use → See [core-workflows.md](core-workflows.md)