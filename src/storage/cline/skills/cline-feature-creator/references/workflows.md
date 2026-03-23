# Creating Workflows

Workflows are markdown files that define step-by-step task automation. Users invoke them with `/workflow-name.md`.

## When to Use

- Sequential processes with a clear start and end
- Repeatable procedures (deploy, test, setup)
- Processes that combine natural language with CLI commands or tool calls
- One purpose per workflow

## Storage Locations

| Scope   | Location                       | Notes                         |
| ------- | ------------------------------ | ----------------------------- |
| Global  | `~/Documents/Cline/Workflows/` | Available across all projects |
| Project | `.clinerules/workflows/`       | Scoped to one project         |

## Anatomy

```markdown
# Workflow Title

Brief description of what this accomplishes.

## Step 1: [Action Name]

Instructions for this step.

## Step 2: [Action Name]

Instructions for this step.

## Step 3: [Action Name]

Instructions for this step.
```

## What Workflows Can Use

### Natural Language

```markdown
## Step 1: Check prerequisites

Verify the development server is running and all dependencies are installed.
```

### CLI Commands

```markdown
## Step 2: Run tests

Execute the test suite:
\`\`\`bash
npm run test
\`\`\`
```

### Cline Tool Syntax (XML)

For precise, guaranteed behavior:

```xml
<execute_command>
  <command>npm run test</command>
  <requires_approval>false</requires_approval>
</execute_command>
```

```xml
<ask_followup_question>
  <question>Deploy to production or staging?</question>
  <options>["Production", "Staging", "Cancel"]</options>
</ask_followup_question>
```

### MCP Tools

Any MCP tools configured in the project can be invoked from workflows.

## Best Practices

- Start with natural language instructions, add XML tool calls only for guaranteed behavior
- Be specific about decision points — offer options, not open-ended questions
- Include failure handling: "If the build fails, read the error output and fix before proceeding"
- Keep workflows focused — one purpose per file
- Name the file descriptively: `deploy-staging.md`, `setup-new-service.md`

## Common Patterns

### Deploy Workflow

```markdown
# Deploy to Staging

## Step 1: Verify clean state

Run `git status` and confirm no uncommitted changes.

## Step 2: Run tests

\`\`\`bash
npm run test
\`\`\`
If tests fail, fix failures before proceeding.

## Step 3: Build

\`\`\`bash
npm run build
\`\`\`

## Step 4: Deploy

\`\`\`bash
npm run deploy:staging
\`\`\`

## Step 5: Verify

Open the staging URL and confirm the deployment is healthy.
```

### Setup Workflow

```markdown
# Set Up New Microservice

## Step 1: Create directory structure

Create the standard service layout under `services/[name]/`.

## Step 2: Initialize package

\`\`\`bash
cd services/[name] && npm init -y
\`\`\`

## Step 3: Add dependencies

Install the standard service dependencies.

## Step 4: Generate boilerplate

Create index.ts, routes.ts, and health-check endpoint using project conventions.
```

## Verification

After creating a workflow, verify:

1. File is saved to the correct location with a descriptive name
2. Steps are numbered and sequential
3. Each step has a clear action and success criteria
4. Failure handling is included where steps can fail
5. The workflow can be invoked with `/workflow-name.md`
