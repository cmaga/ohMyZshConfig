# Creating Hooks

Hooks are scripts that run automatically at key moments in Cline's workflow. They receive JSON via stdin and return JSON via stdout.

## When to Use

- Quality gates (block dangerous operations)
- Automatic enforcement (linting, format checks)
- Context injection (add project info when tasks start)
- Logging and analytics (track tool usage)
- External integrations (notify services)

## Storage Locations

| Scope   | Location                   | Notes                   |
| ------- | -------------------------- | ----------------------- |
| Global  | `~/Documents/Cline/Hooks/` | Applies to all projects |
| Project | `.clinerules/hooks/`       | Scoped to one project   |

## Hook Types

| Type             | When It Runs               | Common Use                         |
| ---------------- | -------------------------- | ---------------------------------- |
| TaskStart        | New task begins            | Inject context, set up environment |
| TaskResume       | Interrupted task resumes   | Restore state                      |
| TaskCancel       | Task cancelled             | Cleanup                            |
| TaskComplete     | Task finishes successfully | Notify, log                        |
| PreToolUse       | Before tool executes       | Block operations, validate         |
| PostToolUse      | After tool completes       | Lint, format, log                  |
| UserPromptSubmit | User sends message         | Transform input, add context       |
| PreCompact       | Before context truncation  | Preserve critical info             |

## Input/Output Schema

### Input (JSON via stdin)

```json
{
  "taskId": "abc123",
  "workspacePath": "/path/to/project",
  "preToolUse": {
    "tool": "write_to_file",
    "parameters": {
      "path": "src/config.ts"
    }
  }
}
```

The input object varies by hook type. `preToolUse` and `postToolUse` include tool details. `taskId` and `workspacePath` are always present.

### Output (JSON via stdout)

```json
{
  "cancel": false,
  "contextModification": "Optional text to inject into context",
  "errorMessage": ""
}
```

| Field                 | Type    | Purpose                            |
| --------------------- | ------- | ---------------------------------- |
| `cancel`              | boolean | Set `true` to block the operation  |
| `contextModification` | string  | Text injected into Cline's context |
| `errorMessage`        | string  | Shown to user when `cancel: true`  |

## Script Template

```bash
#!/bin/bash
INPUT=$(cat)

# Parse relevant fields
TOOL=$(echo "$INPUT" | jq -r '.preToolUse.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.preToolUse.parameters.path // empty')

# Your logic here
if [[ "$TOOL" == "write_to_file" && "$FILE_PATH" == *.js ]]; then
  echo '{"cancel":true,"errorMessage":"Use .ts files instead of .js"}'
  exit 0
fi

# Default: allow
echo '{"cancel":false}'
```

## Common Patterns

### Block File Type

```bash
#!/bin/bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.preToolUse.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.preToolUse.parameters.path // empty')

if [[ "$TOOL" == "write_to_file" && "$FILE_PATH" == *.js ]]; then
  echo '{"cancel":true,"errorMessage":"Use .ts files in this project"}'
  exit 0
fi
echo '{"cancel":false}'
```

### Inject Context on Task Start

```bash
#!/bin/bash
INPUT=$(cat)
WORKSPACE=$(echo "$INPUT" | jq -r '.workspacePath')

# Read project brief and inject into context
BRIEF=$(cat "$WORKSPACE/.cline-project/workflows/memory-bank/projectBrief.md" 2>/dev/null || echo "")
if [[ -n "$BRIEF" ]]; then
  echo "{\"cancel\":false,\"contextModification\":\"Project context: $BRIEF\"}"
else
  echo '{"cancel":false}'
fi
```

### Post-Save Linting

```bash
#!/bin/bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.postToolUse.tool // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.postToolUse.parameters.path // empty')

if [[ "$TOOL" == "write_to_file" && "$FILE_PATH" == *.ts ]]; then
  LINT_OUTPUT=$(npx eslint "$FILE_PATH" 2>&1 || true)
  if [[ -n "$LINT_OUTPUT" ]]; then
    echo "{\"cancel\":false,\"contextModification\":\"Lint issues found: $LINT_OUTPUT\"}"
    exit 0
  fi
fi
echo '{"cancel":false}'
```

## Best Practices

- Keep hooks deterministic — no LLM calls, just script logic
- Use `jq` for JSON parsing (reliable, available on most systems)
- Always provide a default fallback: `echo '{"cancel":false}'`
- Handle missing fields gracefully with `// empty` in jq
- Make hooks fast — they run synchronously and block Cline
- Use ANSI-C quoting (`$'...'`) for escape sequences in output

## Verification

After creating a hook, verify:

1. Script is executable: `chmod +x hook-name.sh`
2. Test with sample input: `echo '{"taskId":"test","workspacePath":"/tmp"}' | ./hook-name.sh`
3. Output is valid JSON: pipe output through `jq .`
4. Script handles missing fields without errors
5. Script exits quickly (under 1 second)
