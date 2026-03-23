# Creating Agent Configs

Agent configs define named subagents with custom system prompts that run as
read-only analysis tools inside Cline.

## When to Use

- Specialized analysis or review (security, architecture, testing)
- Parallel evaluation tasks (run multiple reviewers simultaneously)
- Any read-only task that benefits from a focused persona
- When you want a reusable analysis tool available across all projects

## How They Work

Each YAML file in `~/Documents/Cline/Agents/` registers as a dedicated tool
named `use_subagent_[name]`. Cline auto-discovers them — no restart needed.

## Storage Location

| Scope  | Location                    | Notes                                 |
| ------ | --------------------------- | ------------------------------------- |
| Global | `~/Documents/Cline/Agents/` | Available across all projects         |
| Repo   | `src/storage/cline/agents/` | Version controlled, deployed globally |

## File Format

YAML with frontmatter and a markdown body:

```yaml
---
name: agent-name
description: What this agent does. Use when [triggers].
tools: read_file, list_files, search_files
modelId: claude-sonnet-4-20250514
---

You are a [role]. Your job is to [purpose].

## What to Look For

- [focus area 1]
- [focus area 2]

## Output Format

[how to structure findings]
```

## Frontmatter Fields

| Field       | Required | Description                                             |
| ----------- | -------- | ------------------------------------------------------- |
| name        | Yes      | Display name, becomes the tool name                     |
| description | Yes      | What the agent does (triggers tool selection)           |
| tools       | No       | Allowed tools (defaults to read-only + execute_command) |
| skills      | No       | Restrict which skills the agent can use                 |
| modelId     | No       | Override the model for this agent                       |

## Body (System Prompt)

The markdown body after the closing `---` is the system prompt. Keep it focused:

- Define the role in one line
- List what to look for (bulleted, specific)
- Define the output format (so results are consistent and parseable)
- Stay under 100 lines — subagents have limited context

## Tool Restrictions

For review/analysis agents, restrict to read-only tools:

```yaml
tools: read_file, list_files, search_files, list_code_definition_names
```

For agents that need to run checks:

```yaml
tools: read_file, list_files, search_files, execute_command
```

## Naming Convention

Use kebab-case matching the file name: `security-reviewer.yaml` with `name: security-reviewer`.

## Verification

After creating an agent config:

1. File is valid YAML with `---` frontmatter delimiters
2. `name` field matches the filename (minus extension)
3. `description` is specific enough to trigger on relevant tasks
4. Body is under 100 lines
5. Tools are restricted to what the agent actually needs
