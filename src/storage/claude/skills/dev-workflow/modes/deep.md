# Deep Tier

Architectural or cross-module changes, and every `new take` flow. Iterative scoping, QA planning, architecture review, worker implementation, rigorous parent review.

## Critical Rules

- Use the progressive format from [../SKILL.md](../SKILL.md) for the entire scoping and review phases.
- The plan lives on disk as a worker-handoff artifact. The user reads chat, not the file.
- The `plan-review-agent` reviews the draft plan before workers dispatch. The user accepts, adjusts, or overrides each finding.
- Test-planning is inline by the parent. QA-planning is delegated to `qa-planner-agent`.

## Process

### 1. Iterative scoping

Read affected files silently. The first scoping message lands in the terminal in this order, top to bottom:

1.  `### Detail` — investigation findings, precedents, affected-file audits, alternatives ruled out, side findings. Skim-able bullets, not prose. This is the scroll-up archive: the user reads it only if the lead below feels off.
2.  A horizontal rule (`---`).
3.  The three-beat lead — same shape as the [Pre-dispatch gate](../SKILL.md#pre-dispatch-gate), adapted for scoping:
    - **The problem** — what the user can't do today, in 1 sentence, plain language.
    - **The proposed fix** — one recommended approach, 1-2 sentences. Not all options. Alternatives you weighed go in `### Detail`, not here.
    - **Where I am** — one sentence: confidence 1-10 and the single thing you'd most want to verify before locking in.
4.  Binary ask: *Agree on framing, or push back?*

The lead is the closing of the message — nothing renders below the binary ask. The user's eye lands on the decision point when the terminal stops scrolling; they scroll up into `### Detail` only if something feels wrong.

Hold open questions until the user accepts the framing. Then surface the single highest-leverage one. Loop confidence questions one at a time, never bundled.

### 2. Draft the plan

Write `.claude-artifacts/workflows/dev-workflow/plan.md` inside the worktree using [../templates/plan-template.md](../templates/plan-template.md) as the structure. Length is whatever the workers need to execute unambiguously — the user reads the chat brief from the [Pre-dispatch gate](../SKILL.md#pre-dispatch-gate), not the file.

The intent header (Objective, Outcomes, Out of scope, Autonomy, Stop rules) is the contract with workers. The mechanics (Files, Tasks, Tests) are the execution plan. Add an Architecture notes subsection under the mechanics half if patterns or boundaries need calling out.

- Number outcomes (`O-1`, `O-2`, …). Each task card cites the outcome IDs it satisfies.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`. Resolve every hit with the user before finalizing.

Iterate with the user in chat using the progressive format — high level first, drill down on request. The user reads the chat, not the plan file.

### 3. QA planning

Invoke the `qa-planner-agent` subagent. Input:

- The draft plan
- The user-facing surfaces the plan affects (UI, API, CLI)

Append the agent's returned `## QA Plan` section to the plan verbatim.

### 4. Architecture review gate

Invoke the `plan-review-agent` subagent against the draft plan and affected files. Ask for:

- Architecture fit with existing patterns
- Missing edge cases
- Risk concentrations

Present findings. The user accepts, adjusts, or overrides each. Update the plan accordingly.

### 5. Finalize plan

Confirm every `[NEEDS CLARIFICATION]` is resolved.

Render the [Pre-dispatch gate](../SKILL.md#pre-dispatch-gate) and wait for user approval before dispatching.

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

### 8. Route to wrap-up in [../SKILL.md](../SKILL.md).
