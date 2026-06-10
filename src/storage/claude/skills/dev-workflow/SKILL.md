---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup [TICKET]" to tear down after a PR is merged. Handles small/medium/deep tiers with worker subagents, parent review, PR creation, ticket transition, and worktree cleanup.
---

# Dev Workflow

Single orchestrated flow for ticket-driven and manual implementation work. The parent session is opus; implementation workers are sonnet. Scoping is done first, tiers are for implementation.

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

### Scoping Process

The scoping process to begin to load the correct context for both the user and the session. All steps must be done sequentially.

1. **Codebase update** In the main checkout, run `git status --porcelain`. If it prints anything, stop: this is the main-checkout gate (see Critical Rules). When it prints nothing, run `git pull --ff-only`.
2. **Transition the ticket** to "In Progress" via the `jira` skill.
3. **Understanding The Ticket** If a ticket was provided, read it and its information via the `jira` skill. Otherwise use the user-provided context. Then gather context:
   1. Verify the problem exists in code. If mis-represented, ignore how the ticket is written and do your own investigation.
   2. Read relevant documentation
   3. Are there related issues? Does the commit history help us understand where this bug came from? Is it recurring?
4. **Is this needed?** The ticket regardless of how convincingly it is written is not always needed. What are the higher-level implications? Is there a simpler solution? Is the ticket a symptom of a larger problem? Dive deep.
5. **Share the problem scope** Start the conversation with the user. Progress into it slowly.
   1. Start by saying here is what the ticket says we should do and present a very simple summary. Once they understand move to the next step.
   2. Describe if you think the ticket is worth doing as written? should it be changed? should it not be done at all? This will be decided conversationally by the user.
6. **Solution Research** Now that we have decided this is a problem worth solving we need to dive into the best way to solve this problem.
   1. What is the immediate best solution you can think of?
   2. Refine your best solution based on online research, what are industry standards/best practice for the problem space.
   3. Are there any alternatives worth considering? Challenge assumptions you have made that you have not verified exhaustively.
   4. Ask the user how they would like to solve this. Leverage their expertise and creativity, consider it against the solution you're leaning toward, consider it an option at this stage, not a command.
   5. Synthesize all the data you collected and decide on an approach you think would be best.
7. **Present Recommendation** Post this exact block to chat. The goal is for the user to glance quickly at the conversation, remember the problem, and begin to evaluate the solution. There will likely be some back and forth, refining the solution.

   ```md
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

   <what we'd build, simple and high level. Patterns and integration points, not files.>

   ## Confidence: <1-10>/10

   <one-sentence rationale>
   ```

8. Recommend a tier based on the user-chosen solution.
9. **Create/update the ticket**: If `new take`, create a new ticket. If we chose a solution very different from the original ticket, update the original. Use the `jira` skill.
10. **Enter the worktree.**
    - Call `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
    - Verify with `git rev-parse --show-toplevel` that you're inside the worktree. Then proceed with the tier sequence for the implementation.

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

## Critical Rules

- Never automatically merge a PR. The user merges or asks you to merge.
- Main-checkout gate: before any pull or write in the main checkout, `git status --porcelain` must print nothing. If it prints anything, stop, show the user the dirty files, and wait for their decision. Never stash, commit, or discard main-checkout changes to unblock yourself; all work happens in worktrees, so a dirty main checkout is an anomaly only the user can triage.
- All tiers run in an isolated worktree. Create it before any file modification.
- Classification is Claude-proposed, user-confirmed.
- Keep discussions with the user simple and high level unless they ask for more information. THIS IS **CRUCIAL**! Otherwise you waste time where they keep having to ask you to explain or they just rubber stamp.
