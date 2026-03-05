# Customization

## Overview

Five systems for customizing Cline:

| System | Purpose | When Active |
|--------|---------|-------------|
| Rules | Define behavior | Always (or conditionally) |
| Skills | Domain expertise | On-demand when triggered |
| Workflows | Task automation | Invoked with `/workflow.md` |
| Hooks | Inject custom logic | Automatically on events |
| .clineignore | Control file access | Always |

## Storage Locations

| System | Global | Project |
|--------|--------|---------|
| Rules | `~/Documents/Cline/Rules/` | `.clinerules/` |
| Skills | `~/.cline/skills/` | `.cline/skills/` |
| Workflows | `~/Documents/Cline/Workflows/` | `.clinerules/workflows/` |
| Hooks | `~/Documents/Cline/Hooks/` | `.clinerules/hooks/` |
| .clineignore | N/A | `.clineignore` |

Project-specific takes precedence (except Skills where global wins).

---

## Rules

Markdown files with persistent instructions across conversations.

### Supported Types

| Type | Location |
|------|----------|
| Cline Rules | `.clinerules/` |
| Cursor Rules | `.cursorrules` |
| Windsurf Rules | `.windsurfrules` |
| AGENTS.md | `AGENTS.md` |

### Structure

```markdown
# Rule Title

## Category
- Specific instruction
- Example: `like this`
- Reference: see /src/utils/example.ts
```

### Conditional Rules

Activate only when working with matching files. Add YAML frontmatter:

```yaml
---
paths:
  - "src/components/**"
  - "**/*.test.ts"
---

# React Component Guidelines
...
```

Glob patterns:
- `*` - any characters except `/`
- `**` - any characters including `/` (recursive)
- `{a,b}` - match either pattern

Context sources for matching:
- File paths mentioned in prompt
- Open tabs
- Visible editor panes
- Files edited during task

### Best Practices

- Be specific: "Use camelCase for variables" > "Use good names"
- Include why: "Don't modify /legacy (scheduled for removal Q2)"
- Point to examples: "Follow pattern in /src/utils/errors.ts"
- One concern per file
- Keep concise (rules consume context tokens)

---

## Skills

Modular instruction sets loaded on-demand. See [skills.mdx](docs/customization/skills.mdx) for full details.

### Structure

```
my-skill/
├── SKILL.md          # Required: main instructions
├── docs/             # Optional: additional docs
└── scripts/          # Optional: utility scripts
```

### SKILL.md Format

```markdown
---
name: my-skill
description: Brief description of what this skill does.
---

# My Skill

Detailed instructions...
```

### Progressive Loading

| Level | When Loaded | Cost |
|-------|-------------|------|
| Metadata | Always | ~100 tokens |
| Instructions | When triggered | Under 5k tokens |
| Resources | As needed | Unlimited |

### Best Practices

- Name must match directory name exactly
- Description determines when skill triggers (be specific)
- Keep SKILL.md under 5k tokens
- Put detailed info in `docs/` subdirectory
- Use `scripts/` for deterministic operations

---

## Workflows

Markdown files that define step-by-step task automation. Invoke with `/filename.md`.

### Structure

```markdown
# Workflow Title

Description of what this accomplishes.

## Step 1: Check prerequisites
Verify environment is ready.

## Step 2: Run build
Execute the build command:
```bash
npm run build
```

## Step 3: Verify results
Check build completed successfully.
```

### What Workflows Can Use

- **Natural language**: "Run tests and fix failures"
- **Cline tools**: XML syntax for precise control
- **CLI tools**: Any installed command
- **MCP tools**: External service integrations

### Example Tool Syntax

```xml
<execute_command>
  <command>npm run test</command>
  <requires_approval>false</requires_approval>
</execute_command>

<ask_followup_question>
  <question>Deploy to production or staging?</question>
  <options>["Production", "Staging", "Cancel"]</options>
</ask_followup_question>
```

### Best Practices

- Start with natural language, add XML for guaranteed behavior
- Be specific about decision points
- Include failure handling
- Keep workflows focused (one purpose per file)
- Version control in `.clinerules/workflows/`

---

## Hooks

Scripts that run at key moments in Cline's workflow.

### Hook Types

| Type | When It Runs |
|------|--------------|
| TaskStart | New task begins |
| TaskResume | Interrupted task resumes |
| TaskCancel | Task cancelled |
| TaskComplete | Task finishes successfully |
| PreToolUse | Before tool executes |
| PostToolUse | After tool completes |
| UserPromptSubmit | User sends message |
| PreCompact | Before context truncation |

### How Hooks Work

Hooks receive JSON via stdin, return JSON via stdout:

**Input:**
```json
{
  "taskId": "abc123",
  "workspacePath": "/path/to/project",
  "preToolUse": {
    "tool": "write_to_file",
    "parameters": { "path": "src/config.ts" }
  }
}
```

**Output:**
```json
{
  "cancel": false,
  "contextModification": "Optional text to inject",
  "errorMessage": ""
}
```

### Example: Block .js in TypeScript Project

```bash
#!/bin/bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.preToolUse.tool')
FILE_PATH=$(echo "$INPUT" | jq -r '.preToolUse.parameters.path // empty')

if [[ "$TOOL" == "write_to_file" && "$FILE_PATH" == *.js ]]; then
  echo '{"cancel":true,"errorMessage":"Use .ts files instead of .js"}'
  exit 0
fi

echo '{"cancel":false}'
```

### Use Cases

- Block dangerous operations
- Run linters before saves
- Log tool usage for analytics
- Inject project context on task start
- Trigger external services

---

## .clineignore

Controls which files Cline can access. Works like `.gitignore`.

### Pattern Syntax

| Pattern | Matches |
|---------|---------|
| `node_modules/` | node_modules directory |
| `**/node_modules/` | node_modules at any depth |
| `*.csv` | All CSV files |
| `/build/` | build directory at root only |
| `!important.csv` | Exception: don't ignore |

### Common Exclusions

```text
# Dependencies
node_modules/
**/node_modules/

# Build outputs
/build/
/dist/
/.next/

# Large files
*.csv
*.xlsx
*.sqlite

# Generated code
*.min.js
*.map
```

### Behavior

- Excluded files don't appear in file listings
- Excluded from automatic context gathering
- Can still access explicitly via `@/path/to/file`

### Impact

Can reduce starting context from 200k+ tokens to under 50k. Check token usage in task header after adding.

## Cross-References

- Rules + Hooks work together (rules define, hooks enforce)
- Workflows can use MCP tools → See [mcp.md](mcp.md)
- .clineignore affects context → See [core-workflows.md](core-workflows.md)