---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup [TICKET]" to tear down after a PR is merged. Handles small/medium/deep tiers with worker subagents, parent review, PR creation, ticket transition, and worktree cleanup.
---

# Dev Workflow

Single orchestrated flow for ticket-driven and manual implementation work. The parent session is opus; implementation workers are sonnet.

## Critical Rules

- Never automatically merge a PR. The user merges or asks you to merge.
- All tiers run in an isolated worktree. Create it before any file modification.
- Classification is Claude-proposed, user-confirmed.
- Keep discussions with the user simple and high level unless they ask for more information. THIS IS **CRUCIAL**! Otherwise you waste time where they keep having to ask you to explain or they just rubber stamp.

## Trigger routing

Parse the user's message on invocation.

| Input              | Route to                                                                                       |
| ------------------ | ---------------------------------------------------------------------------------------------- |
| `take <TICKET>`    | Scoping → tier sequence                                                                        |
| `new take`         | Scoping → ticket creation → tier sequence                                                      |
| `cleanup [TICKET]` | [common/cleanup.md](common/cleanup.md) (infer ticket if missing, ask if it cannot be inferred) |

## Scoping

Whether or not there's a ticket, investigate first and fully understand the problem. Even when the ticket prescribes a fix, treat that as a hypothesis.

### Tier definitions

| Tier     | When                                                      |
| -------- | --------------------------------------------------------- |
| `small`  | Bug fix, config change, typo, isolated single-file change |
| `medium` | New feature, moderate refactor, 2-5 files                 |
| `deep`   | Architectural, multi-system, new design pattern, 5+ files |

### Process

0. **pull** Always pull the latest version of main first to make sure we're up to date on the latest changes.
1. **Understand the ask.** If a ticket was provided, read it and its information via the `jira` skill. Otherwise use the user-provided context.
2. **Verify load-bearing premises.** Treat the framing as a hypothesis — even the proposed task itself.
   - Do we even need this?
   - Name the assumptions it depends on (third-party API behavior, schema state, existing-code mitigations) and verify the ones that cross a system boundary.
   - Check project documentation.
   - Collect information from the codebase.
   - Ask the user relevant business or product questions.
3. **Re-state the problem.** Re-state in simple terms based on what you've learned. Confirm with the user to refine.
4. **Investigate solutions.** Sketch ≥2 viable approaches before recommending one. Prefer solutions that prevent future mistakes, are self-documenting, and adhere to project architecture and convention — but challenge suboptimal designs and tech debt. Read docs and similar implementations. Then verify the assumption you'd most want a confident answer to — clean solutions are sometimes training-data echoes (a Stripe-style event ID for a Plaid webhook, a TanStack Query pattern in a `useState` codebase); verification tells you which.

5. **Present recommendation + tier.** Post this exact block to chat. Every field filled. No preamble — start with the `### Notes` header. Do not advance to step 6 until the user replies `go` or names a tier.

   Detail above, action below: the terminal cursor lands at the bottom, so the call-to-action must be the last line. Bold is unreliable across terminals; this template uses `###` headers for sections and `##` for the Tier+Confidence line so the decision is the largest text on screen.

   Rules: one line per bullet. No inline parentheticals — push to Notes. Confidence is a bare number; explain any gap as a `Confidence gap:` Notes bullet.

   ```
   ### Notes
   - <judgment call, risk, open question, scope-creep note — one line each>
   - Confidence gap: <what's holding back the missing points>

   ### Alternatives
   - <Option A>. Skip: <one-line reason>.
   - <Option B>. Skip: <one-line reason>.
   (Or, only if truly N/A: "no alternatives — <one-line reason>".)

   ---

   ### Problem
   <what the user can't do today. One sentence.>

   ### Recommendation
   <what we'd build, 1-2 sentences. Patterns and integration points, not files.>

   ## Tier: <small | medium | deep>  ·  Confidence: <1-10>/10
   <one-sentence rationale>

   ▶ Reply `go` to proceed, or name a different tier.
   ```

   If the user pushes back and iteration continues, keep this trimmed footer on every reply so the state stays at their cursor:

   ```
   ### Problem
   <one sentence, revised if framing shifted>

   ### Recommendation
   <1-2 sentences>

   ## Confidence: <n>/10

   ▶ Reply `go` to proceed, or push back.
   ```

6. **Create the ticket** _(`new take` only — skip if a ticket was provided)_. Use the `jira` skill to capture the scoped problem.
7. **Transition the ticket** to "In Progress" via the `jira` skill.
8. **Enter the worktree.**
   - Call `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
   - Verify with `git rev-parse --show-toplevel` that you're inside the worktree.

## Tier sequences

Run the sequence for the confirmed tier. Each step links to its procedure file.

### Small

The parent implements in one pass. No subagents, no plan file.

1. Implement the change(s) directly in the worktree.
2. Add a unit test if applicable and a test suite is set up.
3. Run lint, type checker, and tests on modified files. Fix issues.
4. [Exit](common/exit.md).

### Medium

Parent plans, `worker-agent` subagents implement, parent reviews. The plan must name every file and every step — workers do not make scoping decisions.

1. [Investigate](common/investigate.md)
2. [Plan](common/plan.md)
3. [Present plan](common/plan-presentation.md)
4. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
5. [Parent review](common/parent-review.md)
6. [Exit](common/exit.md)

### Deep

Architectural or cross-module change. Adds QA planning and an architecture review gate before workers dispatch.

1. [Investigate](common/investigate.md)
2. [Plan](common/plan.md)
3. **QA planning.** Invoke `qa-planner-agent` with the draft plan and the user-facing surfaces it affects (UI, API, CLI). Append the agent's `## QA Plan` section to the plan verbatim.
4. **Architecture review.** Invoke `plan-review-agent` against the draft plan and affected files. Ask for: architecture fit, missing edge cases, risk concentrations. Fix obvious issues; surface judgment calls as `[NEEDS CLARIFICATION]` in the plan.
5. [Present plan](common/plan-presentation.md)
6. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
7. [Parent review](common/parent-review.md)
8. [Exit](common/exit.md)
