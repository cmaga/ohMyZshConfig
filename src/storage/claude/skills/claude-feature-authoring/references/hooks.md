# Hooks Authoring Guide

Hooks run deterministic scripts at specific points in Claude Code's lifecycle. Zero context cost for most events; only `SessionStart` and `UserPromptSubmit` inject stdout into context.

## Where to Configure

Hooks live in `settings.json` at any scope:

- `~/.claude/settings.json` — user-level (all projects)
- `.claude/settings.json` — project-level (shared via git)
- `.claude/settings.local.json` — local-only (not committed)

Or in skill/subagent YAML frontmatter (scoped to component lifecycle).

## Hook Events

| Event                | When                                   | Can Block?                    |
| -------------------- | -------------------------------------- | ----------------------------- |
| `SessionStart`       | Session begins/resumes                 | No                            |
| `SessionEnd`         | Session terminates                     | No                            |
| `Setup`              | Triggered via `--init`/`--maintenance` | No                            |
| `UserPromptSubmit`   | User submits prompt, before processing | Yes                           |
| `PreToolUse`         | Before a tool call executes            | Yes                           |
| `PostToolUse`        | After a tool call succeeds             | No                            |
| `PostToolUseFailure` | After a tool call fails                | No                            |
| `PermissionRequest`  | Permission dialog appears              | Yes (allow/deny/ask decision) |
| `Stop`               | Claude finishes responding             | No                            |
| `TaskCompleted`      | Task marked complete                   | No                            |
| `SubagentStart`      | Subagent spawned                       | No                            |
| `SubagentStop`       | Subagent finishes                      | No                            |
| `TeammateIdle`       | Teammate becomes idle                  | No                            |
| `WorktreeCreate`     | Git worktree created                   | No                            |
| `WorktreeDelete`     | Git worktree deleted                   | No                            |
| `Notification`       | Claude sends a notification            | No                            |
| `PreCompact`         | Before compaction                      | No                            |
| `ConfigChange`       | Settings/skills file modified          | No                            |

## Anatomy of a Hook

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ]
  }
}
```

**matcher**: Regex against tool name (for tool events), session type (for SessionStart), or notification type.

## Stdin Schema

Every hook receives JSON on stdin:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.json",
  "cwd": "/project",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "src/app.ts",
    "content": "..."
  }
}
```

Tool events include `tool_name` and `tool_input`. Use `jq` to extract values:

```bash
jq -r '.tool_input.file_path'
```

## Hook Types

### Command hooks

Run a shell command. Receive JSON input via stdin.

```json
{ "type": "command", "command": "./scripts/validate.sh" }
```

Use `$CLAUDE_PROJECT_DIR` for project-relative paths:

```json
{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/scripts/validate.sh" }
```

### Prompt hooks

Single LLM call to make a decision. Return `{"ok": true/false, "reason": "..."}`.

```json
{ "type": "prompt", "prompt": "Is this SQL query read-only? $ARGUMENTS" }
```

`$ARGUMENTS` interpolates the relevant event data (tool input for tool events, user message for UserPromptSubmit).

### Agent hooks

Spawn a subagent that can use tools (Read, Grep, etc.) to verify conditions. Default 60s timeout.

```json
{ "type": "agent", "prompt": "Verify all tests pass.", "timeout": 120 }
```

### HTTP hooks

POST to an endpoint. Non-2xx = non-blocking error.

```json
{ "type": "http", "url": "http://localhost:8080/validate", "timeout": 30 }
```

## Exit Codes (Command Hooks)

| Code               | Meaning                                                     |
| ------------------ | ----------------------------------------------------------- |
| 0                  | Success — proceed normally                                  |
| 2                  | Blocking error — tool call prevented (for blockable events) |
| Any other non-zero | Non-blocking error — logged, execution continues            |

## JSON Output

Command hooks can output JSON to control behavior:

```json
{
  "continue": false,
  "stopReason": "Build failed, fix errors before continuing"
}
```

### Hook-Specific Output

For PreToolUse, use `hookSpecificOutput` for fine-grained control:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "rm commands are blocked"
  }
}
```

**updatedInput** (PreToolUse only): Modify tool inputs before execution. Enables transparent sandboxing, path correction, parameter injection:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "updatedInput": {
      "file_path": "/sandbox/src/app.ts",
      "content": "..."
    }
  }
}
```

**additionalContext**: Inject context into the conversation (works with PreToolUse, PostToolUse, SessionStart, UserPromptSubmit, Setup):

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Current sprint: auth-refactor. Run tests before committing."
  }
}
```

## Hook Behavior

- **Parallel execution**: All matching hooks for an event run in parallel, not sequentially
- **Default timeout**: 60 seconds for all hook types; configure via `timeout` field
- **No hot-reload**: Claude snapshots hooks at session start. Edits during a session require `/hooks` to review

## Common Patterns

### Block dangerous commands

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/scripts/block-rm.sh"
          }
        ]
      }
    ]
  }
}
```

### Desktop notification when Claude needs input

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude needs input\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

### Inject context on session resume

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Current sprint: auth-refactor. Run bun test before committing.'"
          }
        ]
      }
    ]
  }
}
```

## Debugging

- `/hooks` — read-only browser for inspecting configured hooks
- `$CLAUDE_ENV_FILE` — SessionStart hooks can write env vars here to persist for subsequent Bash commands

## Hooks in Skills/Subagents

Hooks in YAML frontmatter are scoped to the component's lifetime:

```yaml
---
name: secure-ops
description: Operations with security validation
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```
