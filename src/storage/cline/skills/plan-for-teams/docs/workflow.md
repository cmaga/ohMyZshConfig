# Plan for Teams — Workflow

## Step 1: Extract Decisions

Before writing anything, scan the conversation and extract:

1. **What's being built** — feature description, user stories, acceptance criteria
2. **Architecture decisions** — tech choices, patterns, approaches decided on
3. **File boundaries** — which files/modules are affected
4. **Open questions** — anything still unresolved (ask the user NOW)
5. **Dependencies** — what must be built before what
6. **Verification** — how to know each piece is done (test commands, build checks)

If anything critical is ambiguous, ask the user before proceeding. Do not guess
on architecture decisions. You may ask up to 5 focused questions.

## Step 2: Classify Size

Auto-detect the plan size based on these criteria:

| Size       | Files touched | Agents needed | Characteristics                                                                                          |
| ---------- | ------------- | ------------- | -------------------------------------------------------------------------------------------------------- |
| **Small**  | 1-3           | 1-2           | Bug fix, config change, single-module feature, isolated change. One clear implementation path.           |
| **Medium** | 3-8           | 3-4           | Feature touching multiple modules, API + frontend, backend + tests. Needs coordination but not research. |
| **Large**  | 8+            | 4-6           | Architectural change, multi-module feature, cross-cutting concerns. Multiple independent work streams.   |

Present your classification to the user with a one-line justification. They can
override.

## Step 3: Select Agents

Read the agent personas from the `agents/` directory in this skill. Choose which
agents the plan needs based on the work. Common patterns:

**Small:**

- 1 Implementer (general purpose)
- 1 Reviewer (optional, for anything touching auth/payments/data)

**Medium:**

- 2-3 Specialists (pick from: backend-engineer, frontend-specialist, database-engineer, test-engineer)
- 1 Reviewer

**Large:**

- 3-5 Specialists (domain-appropriate)
- 1 Reviewer

Read each selected agent's `.md` file from `agents/` to get their persona
definition. These get embedded directly in the plan.

## Step 4: Build the Dependency Graph

Map out the tasks and their dependencies. Key rules:

- **Foundation tasks** (schemas, shared types, configs) have no dependencies
- **Implementation tasks** depend on their foundation
- **Integration tasks** depend on the components they integrate
- **Review/validation** depends on everything

Think in **waves**:

- Wave 1: Foundation work (no dependencies, must complete first)
- Wave 2+: Parallel work that depends on Wave 1 output
- Final wave: Review and validation

## Step 5: Define Contracts

For each wave boundary, define what the completing wave MUST produce that the
next wave needs. Contracts are concrete:

- Database schema → exact table definitions, TypeScript types
- API endpoints → route signatures, request/response shapes
- Shared types → interface definitions, enums

These contracts get injected into downstream agent spawn prompts. Without them,
agents guess independently and integration fails.

**Contract format in the plan:**

```
### Contract: [name]
Produced by: [agent name] (Wave N)
Consumed by: [agent names] (Wave N+1)
Content: [describe exactly what this agent must output — file paths, type
definitions, interface shapes. Be specific enough that the lead knows what
to extract from the completing agent's work and paste into the next spawn prompt.]
```

## Step 6: Write Validation

Every task needs a verification command. Every plan needs a final validation
section. Use whatever the project already uses:

- `npm test`, `pnpm test`, `pytest`, etc.
- `npm run lint`, `npm run build`
- Specific test grep patterns for the feature
- curl commands for API endpoints
- Manual verification steps if no automated option exists

## Step 7: Generate the Plan

Read the appropriate template from `templates/` based on the classified size
(small.md, medium.md, or large.md). Fill in all sections. The output is a
single markdown file.

**Save the plan to the project root as:** `.claude/plans/<descriptive-slug>.md`

Create the `.claude/plans/` directory if it doesn't exist.

Present the plan to the user for review. They may want to adjust before
handing off to Claude Code.

## Step 8: Handoff Instructions

After the user approves the plan, tell them:

```
Plan saved to .claude/plans/<slug>.md

To execute in Claude Code:
1. Open your terminal in the project root
2. Run: claude
3. Paste: "Read and execute the plan at .claude/plans/<slug>.md using Agent Teams. Use delegate mode — coordinate only, do not implement yourself."
```
