# Deep Tier

Architectural or cross-module changes, and every `new take` flow. Iterative scoping, plan-mode gate, QA planning, architecture review, worker implementation, rigorous parent review.

## Critical Rules

- Use the progressive format from [../SKILL.md](../SKILL.md) for the entire scoping and review phases.
- Plan mode holds the user's attention. Do not exit plan mode until the plan is final.
- The `code-review-agent` reviews the draft plan before workers dispatch. The user accepts, adjusts, or overrides each finding.
- Test-planning is inline by the parent. QA-planning is delegated to `qa-planner-agent`.

## Process

### 1. Iterative scoping

- Read affected files silently.
- Present understanding at the highest level first: what, why, blast radius, top-level change list.
- Ask which items the user wants expanded — do not pre-expand.
- Score your confidence 1-10. If below 10, bundle targeted questions, loop until 10.

### 2. Enter plan mode

Call `EnterPlanMode`.

Draft the plan using [../templates/plan-template.md](../templates/plan-template.md) as the structure. Target 100-300 lines. Past 500 means you have over-specified — cut.

The intent header (Objective, Outcomes, Out of scope, Autonomy, Stop rules) is the contract with workers. The mechanics (Files, Tasks, Tests) are the execution plan. Add an Architecture notes subsection under the mechanics half if patterns or boundaries need calling out.

- Number outcomes (`O-1`, `O-2`, …). Each task card cites the outcome IDs it satisfies.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`. Resolve every hit with the user before exiting plan mode.

Iterate with the user using the progressive format — high level first, drill down on request.

### 3. QA planning

Invoke the `qa-planner-agent` subagent. Input:

- The draft plan
- The user-facing surfaces the plan affects (UI, API, CLI)

Append the agent's returned `## QA Plan` section to the plan verbatim.

### 4. Architecture review gate

Invoke the `code-review-agent` subagent against the draft plan and affected files. Ask for:

- Architecture fit with existing patterns
- Missing edge cases
- Risk concentrations

Present findings. The user accepts, adjusts, or overrides each. Update the plan accordingly.

### 5. Finalize plan

Write the final plan to `.claude-artifacts/workflows/dev-workflow/plan.md` in the worktree.

Call `ExitPlanMode`.

### 6. Dispatch workers

- One `worker-agent` per task.
- Run in parallel where tasks touch disjoint files.
- Pass each worker its task card inline (the T-N block from the plan), not the whole plan. The worker can read `plan.md` if it needs to disambiguate.

### 7. Parent review, tests, and build

After every worker reports:

- Read each diff.
- Verify pattern adherence against the plan's architecture notes.
- Write the unit and programmatic tests from the test plan.
- Run the full test suite. Fix failures.
- Run the build. Fix failures.

### 8. Route to the shared exit in [../SKILL.md](../SKILL.md).
