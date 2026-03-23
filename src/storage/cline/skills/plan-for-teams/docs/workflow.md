# Plan for Teams — Workflow

## Critical Rules

- The plan is self-contained — the Claude Code lead has zero context from the Cline conversation
- No two agents touch the same file — assign shared files to the earlier wave
- Contracts are mandatory for multi-wave plans — without them, integration fails
- Write contracts to disk in addition to messages — files survive context compaction

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

## Step 3: Select Agents and Run Reviews

This step has two phases: review the draft plan with Cline subagents, then
assign Claude Code team agents for the output plan.

### Phase 1: Cline Subagent Review

Before finalizing the plan, run the review subagents to catch issues early.
These are Cline Agent Configs invoked as tools during plan creation:

1. **Security Reviewer** (`use_subagent_security-reviewer`) — Pass the extracted
   decisions, file boundaries, and architecture choices. It will flag auth gaps,
   injection risks, data exposure, and secrets handling issues.
2. **Tech Lead Reviewer** (`use_subagent_techlead-reviewer`) — Pass the same
   context. It will flag pattern violations, tech debt risks, and architectural
   concerns.

Incorporate their findings into the plan. If they flag critical issues, surface
them to the user before proceeding.

For **Small** plans: reviews are optional. Skip if the change is trivial
(config, copy, isolated bug fix).

For **Medium/Large** plans: both reviews are mandatory.

### Phase 2: Claude Code Team Agent Assignment

Assign agents for the generated plan that Claude Code's lead will spawn:

**Small:**

- 1 Implementer

**Medium:**

- 1-2 Implementers (split by wave or module)
- 1 Reviewer

**Large:**

- 2-4 Implementers (one per independent work stream)
- 1 Reviewer

Read `agents/implementer.md` and `agents/reviewer.md` from this skill to get
their persona definitions. These get embedded directly in the plan as spawn
prompts for Claude Code's lead agent.

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

## Pre-Handoff Verification

Before presenting the plan to the user, verify:

1. Every task has a verification command
2. No file appears in more than one agent's ownership list
3. Every multi-wave plan has contracts defined for each wave boundary
4. Every agent section has a complete spawn prompt (not just a reference)
5. Acceptance criteria are concrete and testable
6. The plan makes zero references to "the conversation" or "as discussed"
