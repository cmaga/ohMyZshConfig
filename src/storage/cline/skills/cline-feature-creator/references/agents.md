# Custom Subagent Configuration Guide

## Overview

Cline supports file-based agent configurations that let you define named subagents with custom system prompts, restricted tool sets, skill filters, and model overrides. Each agent config becomes a dedicated tool (e.g., `use_subagent_security_reviewer`) that Cline can invoke alongside the generic `use_subagents` tool.

## Prerequisites

1. **Enable Subagents**: Settings > Features > Agent section > toggle **Subagents** on
2. **Create the agents directory**: `~/Documents/Cline/Agents/`
3. Drop `.yaml` or `.yml` files into that directory

The directory is watched in real-time via `chokidar`. Adding, editing, or removing YAML files triggers an automatic reload - no restart needed.

## File Format

Each agent config is a single YAML file with two parts:

1. **YAML frontmatter** (between `---` delimiters) - metadata fields
2. **Body** (everything after the closing `---`) - the system prompt

```yaml
---
name: my-agent
description: What this agent does
tools: read_file, list_files, search_files
skills: my-skill-name
modelId: claude-sonnet-4-20250514
---
You are a specialist. Your role is to...
```

## Field Reference

### `name` (required, string)

The display name for the agent. Used for:

- **Tool name generation**: Normalized into a tool name like `use_subagent_{name}` (spaces become underscores, special chars stripped, max 64 chars). This is the tool name the model sees and invokes.
- **Config lookup key**: Configs are cached by lowercased name. If two files define the same name, the last one loaded wins (files are sorted alphabetically).
- **Agent identity in system prompt**: Injected as `Name: {name}` in an `# Agent Profile` section appended to the system prompt.
- **Approval UI**: Shown in the approval dialog as "Cline wants to use the '{name}' subagent".

### `description` (required, string)

What the agent does. Used for:

- **Tool description for the model**: The model sees `Use the "{name}" subagent: {description}` as the tool's description. This is how the model decides when to use your agent, so make it specific.
- **Agent identity in system prompt**: Injected as `Description: {description}` in the `# Agent Profile` section.

### `tools` (optional, string or string array)

Which Cline tools the subagent is allowed to use. Accepts either a comma-separated string or a YAML array. If omitted or empty, falls back to the default set.

**Default tools** (when not specified):

- `read_file`
- `list_files`
- `search_files`
- `list_code_definition_names`
- `execute_command`
- `use_skill`

`attempt_completion` is always included regardless of configuration - it's how the subagent returns results.

**Available tool IDs** (these are the `ClineDefaultTool` enum values):

| Tool ID                      | Purpose                                            |
| ---------------------------- | -------------------------------------------------- |
| `read_file`                  | Read file contents                                 |
| `list_files`                 | List directory contents                            |
| `search_files`               | Regex search across files                          |
| `list_code_definition_names` | List top-level code definitions                    |
| `execute_command`            | Run shell commands (read-only in subagent context) |
| `use_skill`                  | Load and activate skills                           |
| `write_to_file`              | Write file contents (not in defaults)              |
| `replace_in_file`            | Apply targeted edits to files (not in defaults)    |
| `browser_action`             | Browser automation (not in defaults)               |
| `use_mcp_tool`               | MCP tool access (not in defaults)                  |
| `access_mcp_resource`        | MCP resource access (not in defaults)              |
| `ask_followup_question`      | Ask the user a question (not in defaults)          |
| `plan_mode_respond`          | Respond in plan mode (not in defaults)             |
| `attempt_completion`         | Return final result (always included)              |

Unknown tool names cause a parse error and the config file is skipped.

**Format examples:**

```yaml
# Comma-separated string
tools: read_file, list_files, search_files

# YAML array
tools:
  - read_file
  - list_files
  - search_files
```

### `skills` (optional, string or string array)

Restricts which skills the subagent can use. When specified, only the named skills are available. When omitted, all discovered skills in the workspace are available.

Skills are matched by name against the skills discovered in the current workspace's `.cline/skills/` directory. If a configured skill name doesn't match any discovered skill, a warning is logged and it's silently skipped.

```yaml
# Only allow these specific skills
skills: my-skill, another-skill

# YAML array form
skills:
  - my-skill
  - another-skill
```

### `modelId` (optional, string)

Overrides the model used for this subagent's API requests. The model ID is applied to the current provider's configuration for the active mode (plan or act). If omitted, the subagent uses the same model as the main agent.

```yaml
modelId: claude-sonnet-4-20250514
```

### System Prompt Body (required)

Everything after the closing `---` frontmatter delimiter becomes the agent's system prompt. When present, it **completely replaces** Cline's generated system prompt. The final prompt sent to the API is constructed as:

```
{your custom system prompt}
# Agent Profile
Name: {name}
Description: {description}

# Subagent Execution Mode
You are running as a research subagent. Your job is to explore the codebase...
[built-in subagent suffix with behavioral constraints]
```

The built-in suffix instructs the agent to:

- Explore and gather information to answer the question
- Use `attempt_completion` to return results
- Keep results concise with a "Relevant file paths" section
- Only use `execute_command` for read-only operations
- Not modify files or system state

If the body is empty or whitespace-only, the config fails to parse and is skipped.

## How Tool Resolution Works

1. On startup (and on file changes), `AgentConfigLoader` reads all `.yaml`/`.yml` files from `~/Documents/Cline/Agents/`
2. Each valid config is cached by normalized (lowercased) name
3. Dynamic tool names are generated: `use_subagent_{normalized_name}` (spaces to underscores, non-alphanumeric stripped)
4. These tool names are registered in the global tool name registry via `setDynamicToolUseNames()`
5. When building the system prompt, `ClineToolSet.getDynamicSubagentToolSpecs()` creates tool specs for each config with `description: "Use the '{name}' subagent: {description}"`
6. The model sees these as distinct callable tools alongside the generic `use_subagents`

## Storage Location

| Scope  | Location                    | Notes                                 |
| ------ | --------------------------- | ------------------------------------- |
| Global | `~/Documents/Cline/Agents/` | Available across all projects         |
| Repo   | `src/storage/cline/agents/` | Version controlled, deployed globally |

## Naming Convention

Use kebab-case matching the file name: `security-reviewer.yaml` with `name: security-reviewer`.

## VS Code Validation

Agent YAML files use a frontmatter+body format that standard YAML validators do not understand. The markdown body after the closing `---` is not valid YAML, so VS Code's YAML language server will report false errors. Suppress this with a file association override in `.vscode/settings.json`:

```json
{
  "files.associations": {
    "**/agents/*.yaml": "plaintext",
    "**/agents/*.yml": "plaintext"
  }
}
```

## Example: Security Reviewer

**File**: `~/Documents/Cline/Agents/security-reviewer.yaml`

```yaml
---
name: security-reviewer
description: Reviews code and architecture plans for security vulnerabilities, auth flaws, and data exposure risks
tools: read_file, list_files, search_files, list_code_definition_names, execute_command
---

You are a senior security engineer performing a security review.

Your responsibilities:
- Identify authentication and authorization flaws
- Check for input validation and sanitization issues
- Look for injection vulnerabilities (SQL, XSS, CSRF, command injection)
- Find hardcoded secrets, credentials, or API keys
- Review access control and permission models
- Assess data exposure and privacy risks
- Check dependency security (known vulnerable packages)

For each issue found:
1. State the severity (critical / high / medium / low)
2. Describe the vulnerability and attack vector
3. Reference the specific file and code pattern
4. Suggest a concrete fix

If no issues are found, explicitly state that the reviewed code appears secure and explain what you checked.
```

When Cline sees this config, it registers a tool called `use_subagent_security_reviewer`. You can ask Cline something like "use the security reviewer agent to check the auth module" and it will invoke this agent with your custom system prompt.

## Gotchas

- **Name collisions**: If two files define agents with the same normalized name, the last one alphabetically wins.
- **Tool name length**: Tool names are capped at 64 characters. Long agent names get truncated.
- **Parse errors are silent**: If a YAML file has invalid frontmatter or an empty body, it's skipped with a log warning. Check the Cline output channel if an agent doesn't appear.
- **System prompt replacement**: Your body replaces the _entire_ generated system prompt. The subagent suffix (execution mode constraints) is still appended, but the standard Cline system prompt with capabilities, rules, etc. is not included.
- **Read-only by default**: The default tool set is read-only. You can add `write_to_file` or `replace_in_file` to the tools list, but the built-in subagent suffix still tells the agent not to modify files. If you want a writing agent, you'd need to override that instruction in your system prompt body.
- **No nested subagents**: Subagents cannot spawn their own subagents. The `use_subagents` tool is excluded from subagent runs via `contextRequirements: (ctx) => !ctx.isSubagentRun`.

## Verification

After creating an agent config:

1. File is valid YAML frontmatter with `---` delimiters and a non-empty body
2. `name` field matches the filename (minus extension)
3. `description` is specific enough to trigger on relevant tasks
4. Body is focused and under 100 lines
5. Tools are restricted to what the agent actually needs
6. Agent appears in Cline's tool list (check output channel if not)
