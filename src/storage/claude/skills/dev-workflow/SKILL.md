---
name: dev-workflow
description: End-to-end implementation workflow. Use when the user says "take <TICKET>" to work on an existing Jira ticket, "new take" to scope and create a ticket before working on it, or "cleanup <TICKET>" to tear down after a PR is merged. Handles small/medium/deep tiers with worker subagents, parent review, PR creation, ticket transition, and worktree cleanup.
---

# Dev Workflow

Single orchestrated flow for ticket-driven and manual implementation work. The parent session is opus; implementation workers are sonnet.

## Critical Rules

- Never automatically merge a PR. The user merges or asks you to merge.
- All tiers run in an isolated worktree. Create it before any file modification.
- Classification is Claude-proposed, user-confirmed. Never proceed without confirmation.
- Research before locking. Solutions are guesses — yours and the user's both. Before any plan or fix is final, name the question you'd most want confidence in, then go answer it. Bring back what you found.

## Trigger routing

Parse the user's message on invocation.

| Input                  | Route to                                                |
| ---------------------- | ------------------------------------------------------- |
| `take <TICKET>`        | Fetch ticket, classify, route to tier mode              |
| `take <TICKET> <tier>` | Fetch ticket, skip classification, route to tier mode   |
| `new take`             | Scoping conversation, create ticket, route to `deep.md` |
| `cleanup <TICKET>`     | Route to `modes/cleanup.md`                             |
| `cleanup`              | Route to `modes/cleanup.md` (infer ticket from context) |

## Entry: prepare ticket

### Path A — ticket ID provided (`take <TICKET>`)

1. Fetch via the `jira` skill.
2. Present ticket title and description in 2-3 lines.
3. Propose a tier with one sentence of reasoning.
4. User confirms or overrides.

### Path B — no ticket (`new take`)

1. Ask what the user wants to work on.
2. Scope progressively (see **Progressive format** below).
3. Once scope is clear, create the ticket via the `jira` skill.
4. Route directly to `modes/deep.md`. No classification.

### Tier definitions

| Tier     | When                                                          |
| -------- | ------------------------------------------------------------- |
| `small`  | Bug fix, config change, typo, isolated single-file change     |
| `medium` | New feature, moderate refactor, 2-5 files                     |
| `deep`   | Architectural, cross-module, 5+ files, or any `new take` flow |

## Enter worktree

After ticket is confirmed and tier is set:

1.  Call `EnterWorktree` with a worktree name derived from the ticket: `<TICKET>-<tier>` (e.g., `STAX-123-medium`).
2.  Verify you are now inside the worktree: run `git rev-parse --show-toplevel` and confirm the path matches.
3.  Ensure `.claude-artifacts/` is gitignored for this repo. Idempotent one-liner:

        F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"

4.  Route to the tier's mode file.

## Progressive format

Use this format during all scoping and review conversations with the user. The user skims, then drills down.

- Open with the highest-level framing: name the change and its blast radius in 1-2 sentences.
- List the top-level changes as bullets. Do not expand them.
- Ask the user which bullets they want expanded before going deeper.
- Every multi-point response ends with a `### Summary` section listing decisions made and open questions.

## Research before you lock in

Solutions are guesses. The difference between yours and the user's is shape, not certainty: they bring intuition and context, you bring breadth and search speed. Research is how either of you moves from guess to actual answer.

Before any plan or fix is final, look it up. Start by naming the question you'd most want a confident answer to — that's usually harder than it sounds, and it's where most of the value is. Then go find that answer. Wherever it lives — docs, release notes, a community thread, a blog post, the source — what matters is that you can say what you didn't know and now do.

Bring it back into the conversation with what you think it means. You pick from real options, together.

This is allowed to be curious. If a solution feels clean, that's interesting, not authoritative — clean solutions are sometimes right and sometimes training-data echoes. The research tells you which. The output you're aiming for is a solution you'd be proud of, not one you're defending.

## Shared exit

Every tier mode ends here before returning control.

1. Parent reviews worker output against the plan and existing patterns.
2. Produce a report:
   - **What changed** — file list with one-line purpose each
   - **Deviations from plan** — if any
   - **Verification** — do everything you can to test and verify the change yourself. If you cannot verify something, list it here with one line on why it needs the user.
3. Create PR via the `git-provider` skill.
4. Transition ticket to "in review" via the `jira` skill.
5. Run `code-review-agent` against the PR. If it returns findings, auto-fix what you can, commit as `address code review findings`, and push. One pass only.
6. Final message: summarize any findings that need user decision, remind them to run `cleanup <TICKET>` after merge, and end with the PR URL on its own line.

## Modes

- [modes/small.md](modes/small.md) — parent one-shots in the worktree
- [modes/medium.md](modes/medium.md) — plan, dispatch workers, parent review
- [modes/deep.md](modes/deep.md) — iterative scoping, plan mode, QA planner, review gate, workers, parent review
- [modes/cleanup.md](modes/cleanup.md) — post-merge teardown

## What this skill does NOT do

- Auto-merge PRs
- Auto-classify tickets without user confirmation
- Poll PR state — `cleanup` is always user-initiated
- Run security review — invoke `security-expert-agent` manually when warranted
