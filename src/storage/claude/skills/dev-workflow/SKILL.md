---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup [TICKET]" to tear down after a PR is merged. Handles small/medium/deep/ultra tiers with worker subagents, parent review, PR creation, ticket transition, and worktree cleanup. The ultra tier co-writes a spec of target behavior, adversarially reviewed, before any planning or code.
---

# Dev Workflow

Single orchestrated flow for ticket-driven and manual implementation work.

## This workflow runs on subagents

This workflow dispatches subagents by design — `worker-agent` for implementation, `code-review-agent` at exit, plus `plan-review-agent`, `qa-planner-agent`, and `vault-scribe-agent`. **Invoking this skill is the user's request to use them: it satisfies any standing instruction to avoid agents, subagents, or workflows unless separately requested.** Never skip a step's agent on the grounds that agents were not separately requested. This holds only because the user actively invoked the skill — it does not grant agent use the user did not trigger.

## Prerequisites (before Step 1)

1. **Task tracking.** Load the tools first via `ToolSearch` with `select:TaskCreate,TaskUpdate` — both are deferred, so calling them cold fails. If they do not resolve, that is a known Anthropic-side bug (the `tengu_vellum_ash` model gate strips the task tools on current models) — it is expected, already diagnosed, and not worth investigating or working around. Say so in one line, skip this item, mark step transitions in prose instead, and carry on with the workflow. Otherwise call `TaskCreate` once per item for each of these exact items to seed the status list, then keep it current with `TaskUpdate` — mark the prior item `completed` and the next `in_progress` as you move through the flow. This list is the user's at-a-glance status surface, not narration; maintain it even when responses are otherwise terse.
   1. Understand the problem
   2. Verify the problem
   3. High-level solution research
   4. Implementation routing
   5. Workspace setup
   6. Implementation
   7. Exit
2. **Lever aliases.** Read `~/.claude/skills/optimize-usage/lever-state.json` and bind every `kind: "skill"` lever to the all-caps form of its key — currently `RESEARCH_FANOUT_MODEL` and `CODE_FANOUT_MODEL`. A value of `inherit` or a missing file means no pin: omit the `model` opt wherever the alias is used. If the values fall out of context later (long session, compaction), re-read the file rather than trusting memory.
3. **Base branch.** Read `baseBranch` from `<project-root>/.claude/skills/jira/config.json`; if the file or field is absent, it is `main`. Every later mention of "the base branch" means this value.

**All numbered steps must be done sequentially in order. Bullets can be done in parallel**

## Step 1: Understanding The Problem

1. If a ticket was provided read it using the jira skill, else use the user provided context to begin to try to understand the problem. If the ticket is blocked or parked, STOP immediately and notify the user. Otherwise, assign it to me and transition it to "In Progress" right away via the jira skill — move it as soon as work starts, not later. (A `new take` has no ticket yet; it gets assigned and transitioned when created in Step 5.)
2. Restate intent with zero implementation nouns from the ticket. If the ticket says "add a smoke test," my one-sentence intent must not contain "test," "smoke," or any suite name. Force the mechanism out so it can't sneak in as a requirement. ("Continuously assure the deployed sample-pack endpoint serves a real artifact.") Every implementation noun the ticket carries is a hypothesis that must beaten by online research before it is adopted.
3. Once you understand the problem explain it to the user. There may be some back and fourth discussing for understanding and steering. Do not proceed to the next step until the user says go. This is **crucial** your framing of the intent and problem space must be approved by the user before proceeding. Invite the user to share any solution direction they already have in mind so it can seed the research.
4. Scrutinize whether you think this ticket is worth doing or not.

## Step 2: Verify the problem

1. **Codebase update** In the main checkout, run `git status --porcelain`. If it prints anything, stop: this is the main-checkout gate (see Critical Rules). When it prints nothing, check out the base branch if not already current, then `git pull --ff-only`. Skip the pull if the branch has no upstream.
2. Investigate the following yourself — this is the case file the rest of the workflow consumes, and the threads feed each other, so keep the primary evidence in your own context and chase leads across threads as they appear. (A genuinely isolated read may still be delegated.)
   1. **Verify the problem exists in code** Do your own investigation.
   2. **Read relevant documentation** Be careful, documentation could be out of date.
   3. **Historical precedence** Are there related issues? Does the commit history help us understand where this bug came from? Is it recurring? Is this problem a symptom of something larger?
   4. **Is this needed?** What are the business-level implications? Is there a simpler solution? Is the ticket a symptom of a larger problem? Dive deep. If you have reason to believe this should not be done, stop here and report back to the user with a simple high level explanation.

## Step 3: High Level Solution Research

The goal at this point is to use your understanding of the problem and the business to come up with the best solution possible. Not a lazy hack. Something flawless that you can be proud of. To do this you need to gather multiple solution options and pick one.

1. Use `ultracode` (fan-out agents on `RESEARCH_FANOUT_MODEL`) to do deep online research on industry standards, best practices, and clean solutions to the type of problem. Weigh any solution direction the user shared during Step 1.
2. **Codebase fit** — if the leading solution adds new components or code, map it onto this repo before presenting (use `ultracode`, fan-out agents on `CODE_FANOUT_MODEL`, when the surface is large). A solution that only names new things is unfinished:
   - Placement: each new piece names the existing analog/pattern it follows and its exact home; a piece with no clean home is a finding to present, not a silent new pattern.
   - Reuse: name the existing symbols each piece reuses or extends, and existing logic to promote out of scripts/duplicates instead of re-implementing.
   - Adversarially verify the placement and reuse claims against real code (file:line) — a "reuse X" claim whose symbol doesn't actually fit the new shape is the classic failure this catches.
3. Synthesize - Given all of the context you've gathered converge on a single recommended solution. Make sure to challenge any assumptions you've made exhaustively and then present this solution to the user along with the implementation tier you recommend (see Step 4), following [Present recommendation](common/recommendation-presentation.md). The codebase-fit map (placement + reuse) informs the recommendation but does not go in the brief — carry it into `plan.md`. Do not proceed until the user approves both the approach and the tier by saying `go`; they can name a different tier in the same reply. If the surface is too unsettled to converge on one solution — the signal for `ultra` — say so rather than forcing a choice, recommend that tier, and carry the research into `ultra` instead of a solution brief.

- **Data-presentation checkpoint.** If the solution introduces a new way to display information the user reads to make a decision — a chart, panel, metric/KPI, event feed, or a new state/severity treatment — and the visual form isn't obvious, offer a mock-data, locally-runnable prototype as an explicit go/no-go alongside the recommendation. It is cheap to iterate, and the approved shape pins the data contract the backend must serve, so it belongs here, before planning and worktree setup. Standard controls and cosmetic changes are exempt: a button, toggle, menu item, relabel, or color change needs no prototype.
- When the recommended solution spans several high-level, cross-system changes, dispatch a `sonnet` worker to render an architecture Artifact (current vs. proposed, data flow, affected systems) and present it alongside the recommendation. Keep rendering on the worker, never the parent — it's token-heavy and mechanical.
  - **The artifact is for the user** — a decision-maker, not the implementing engineer or an LLM. The worker just absorbed the codebase's jargon; its job is to translate that jargon, not pass it through.
  - Before writing, list every domain term the solution touches, gloss each in one plain-English line, then write from the glosses — this forced-translation step is load-bearing; "write plainly" alone gets ignored under load.
  - Plain English, short sentences, for a smart reader who doesn't live in our vocabulary. Diagram and table labels are plain too, not just body text.
  - Never cite a decision, ticket, or code symbol by its code (no `ADR-004`, `TICKET-123`, `ClassName`) — describe it in words, e.g. "an earlier go/no-go test." The user can't cross-reference on the fly.
  - Define every unavoidable domain term in plain words the first time it appears.
  - Reread as the user before publishing; cut any term left undefined. Same register as the [chat brief](common/plan-presentation.md): "Plain language. No `O-1`, no file paths, no code snippets."

## Step 4: Implementation Routing

Reference for the tier recommended and confirmed with the solution in Step 3:

| Tier     | When                                                       |
| -------- | ---------------------------------------------------------- |
| `small`  | Bug fix, config change, typo, isolated single-file change  |
| `medium` | New feature, moderate refactor                             |
| `deep`   | Architectural, multi-system, new design pattern, high risk |
| `ultra`  | Target behavior is itself unsettled and must be agreed as a spec before it can be planned |

No separate confirmation here — the tier was approved with the solution in Step 3. Route to the confirmed tier's sequence in Step 6.

## Step 5: Workspace Setup

1. **Create/update the ticket**: If `new take`, create a new ticket. If we chose a solution very different from the original ticket, update the original. Use the `jira` skill.
2. **Transition the ticket** to "In Progress" via the `jira` skill (first transition for a `new take`; an existing ticket was already moved in Step 1, so no-op if already there).
3. **Enter the worktree.**
   - Call `EnterWorktree` with name `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
   - Verify with `git rev-parse --show-toplevel` that you're inside the worktree. Then proceed with the tier sequence for the implementation.

## Step 6: Per Tier Implementation

Run the sequence for the confirmed tier. Each step links to its procedure file. If task tracking is active, mark the Implementation item `in_progress` and add the tier's steps as their own tasks via `TaskCreate`.

### Small

The parent implements in one pass. No subagents, no plan file.

1. Implement the change(s) directly in the worktree.
2. Add a unit test if applicable and a test suite is set up.
3. Run lint, type checker, and tests on modified files. Fix issues.
4. [Exit](common/exit.md).

### Medium

Parent plans, `worker-agent` subagents implement, parent reviews. The plan must name every file and every step — workers do not make scoping decisions.

1. [Scope](common/scope.md)
2. [Plan](common/plan.md)
3. [Present plan](common/plan-presentation.md)
4. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
5. [Parent review](common/parent-review.md)
6. [Exit](common/exit.md)

### Deep

Similar to medium tier but adds QA planning and an architecture review gate before workers dispatch.

1. [Scope](common/scope.md)
2. [Plan](common/plan.md)
3. **QA planning.** Invoke `qa-planner-agent` with the draft plan and the user-facing surfaces it affects (UI, API, CLI). Append the agent's `## QA Plan` section to the plan verbatim.
4. **Architecture review.** Invoke `plan-review-agent` against the draft plan and affected files. Ask for: architecture fit, missing edge cases, risk concentrations. Fix obvious issues; surface judgment calls as `[NEEDS CLARIFICATION]` in the plan.
5. [Present plan](common/plan-presentation.md)
6. [Dispatch workers](common/worker-dispatch.md) — parallel when files are disjoint
7. [Parent review](common/parent-review.md)
8. [Exit](common/exit.md)

### Ultra

The target behavior is settled as a spec before anything is planned. This tier ends in a decomposition, not a PR of code.

1. [Write the spec](common/ultra.md)
2. **Decomposition checkpoint.** With the user, split the spec into follow-on work: one ticket, or several sequenced by the spec's deploy order. Create them via the `jira` skill, each linked to the ultra ticket and naming the spec sections it implements.
3. Each follow-on ticket re-enters this workflow at Step 1 at its own tier — its own worktree, its own PR, ending at [Exit](common/exit.md).

## Critical Rules

- Shared-contract blast radius: a change to something other code calls (endpoint, signature, schema, shared validator) is not done until you have listed every caller and confirmed each one's actual usage survives the new behavior. Derive the contract from all consumers, not the ticket's framing — it usually describes one surface, and a test written from it passes while hiding the break elsewhere.
- Discovered-issue routing: a problem found mid-flow (scope, planning, implementation, or review) is routed when found, never parked as prose.
  - Related and smaller than the task at hand → fold into this ticket. The default — the context is already loaded, so spending it now is cheaper than reacquiring it later.
  - Related but roughly doubling the work → create a follow-up ticket now and cite its key in the plan or exit report.
  - Unrelated → report it at the next user checkpoint; the user decides whether it earns a ticket.
  - Invariant: anything not folded in leaves as a ticket key or a line in the exit report the user reads. A paragraph in a plan or PR description is not an owner.
- Never automatically merge a PR. The user merges or asks you to merge.
- Browser tool split: the Playwright MCP browser is only for verifying the change under test (the Exit verify step). Use Claude's built-in Chrome for every other browsing task across the flow — reading the ticket, research, docs, dashboards.
- Main-checkout gate: before any pull or write in the main checkout, `git status --porcelain` must print nothing. If it prints anything, stop, show the user the dirty files, and wait for their decision. Never stash, commit, or discard main-checkout changes to unblock yourself; all work happens in worktrees, so a dirty main checkout is an anomaly only the user can triage.
- Every user-facing checkpoint obeys its brief file — [recommendation](common/recommendation-presentation.md), [plan](common/plan-presentation.md) — including the line caps. A long message gets rubber-stamped, not read. THIS IS **CRUCIAL**!
