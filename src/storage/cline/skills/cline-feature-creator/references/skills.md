# Creating Skills

Skills are modular instruction sets loaded on-demand when triggered by their description.

## When to Use

- Domain expertise or complex knowledge
- Multi-step guided processes
- Anything that needs bundled docs, scripts, or templates
- Heavy documentation that shouldn't consume tokens on unrelated tasks

## Storage Locations

| Scope   | Location           | Notes                         |
| ------- | ------------------ | ----------------------------- |
| Global  | `~/.cline/skills/` | Available across all projects |
| Project | `.cline/skills/`   | Scoped to one project         |

## Anatomy

```
skill-name/
├── SKILL.md          # Required: main instructions
├── docs/             # Optional: additional documentation
├── references/       # Optional: reference material loaded as-needed
├── scripts/          # Optional: executable code for deterministic tasks
├── templates/        # Optional: file templates used in output
└── evals/            # Optional: feedback and improvement tracking
    └── evals.yaml    # Append-only event log (feedback, analyses, changes)
```

## SKILL.md Structure

### Frontmatter (Required)

```yaml
---
name: my-skill
description: What this skill does. Use this skill when [specific triggers]. Even when [edge cases that should still trigger].
---
```

**Name**: Must match the directory name exactly.

**Description**: The primary trigger mechanism. This is what Cline reads to decide whether to load the skill. Write it to be slightly "pushy" — Cline tends to under-trigger.

### Body

```markdown
# Skill Title

Brief description of what this skill does.

## Step 1: [First Action]

Instructions...

## Step 2: [Next Action]

Instructions...
```

## Progressive Loading

| Level                                  | When Loaded    | Budget          |
| -------------------------------------- | -------------- | --------------- |
| Metadata (name + description)          | Always         | ~100 tokens     |
| SKILL.md body                          | When triggered | Under 500 lines |
| Bundled resources (docs/, references/) | As needed      | Unlimited       |

Keep SKILL.md under 500 lines. Move detailed reference material to subdirectories with clear pointers:

```markdown
For API details, read [docs/api-reference.md](docs/api-reference.md)
```

## Domain Organization

When a skill supports multiple variants (frameworks, providers, platforms), organize by variant:

```
cloud-deploy/
├── SKILL.md              # Workflow + selection logic
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

SKILL.md routes to the relevant reference. Only one gets loaded per invocation.

## Mode Pattern

For skills with distinct operational modes, use a modes directory:

```
my-skill/
├── SKILL.md              # Mode detection + routing
└── modes/
    ├── setup.md
    ├── operate.md
    └── troubleshoot.md
```

SKILL.md detects the mode from user intent and routes to the correct file.

## Scripts

Use scripts for deterministic, repeatable tasks. Scripts execute without being loaded into context.

```
my-skill/
└── scripts/
    └── validate.sh       # Run validation checks
```

Reference from SKILL.md: `Run scripts/validate.sh to verify the setup`

## Feedback Collection Pattern

Add this section at the bottom of every created skill's SKILL.md:

```markdown
## Post-Completion

When the task using this skill is complete, ask the user:
"How did that go? Anything that worked well or needs improvement?"

If the user provides feedback, append a feedback entry to `evals/evals.yaml`:

- type: feedback
  id: [next sequential integer]
  date: [YYYY-MM-DD]
  task: [brief description of the task]
  worked: [what went well]
  issues: [what went wrong or could be better]
  severity: low|medium|high
```

## Eval System

Every skill created by the cline-feature-creator includes `evals/evals.yaml` — a single append-only event log. See [templates/evals.yaml](../templates/evals.yaml) for the template and schema.

The log contains three entry types in chronological order:

- **feedback**: User feedback after using the skill (appended after each use)
- **analysis**: Pattern analysis during Improve mode (appended during improve cycles)
- **change**: Modifications applied to the skill (appended after changes, including reverts with lessons learned)

Reading the log chronologically shows causality: which feedback triggered which analysis, which analysis led to which change, and whether the change resolved the issue.

## Verification

After creating a skill, verify:

1. Directory name matches `name` field in frontmatter
2. Description is specific and includes trigger contexts
3. SKILL.md body is under 500 lines
4. All file references point to files that exist
5. Run structural validation: `python scripts/validate.py <path-to-skill>`
