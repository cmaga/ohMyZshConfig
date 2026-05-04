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
2. Transition the ticket to "In Progress" via the `jira` skill. Skip silently if it is already in that state.
3. Present ticket title and description in 2-3 lines.
4. Propose a tier with one sentence of reasoning.
5. User confirms or overrides.

### Path B — no ticket (`new take`)

1. Ask what the user wants to work on.
2. Scope progressively (see **Progressive format** below).
3. Once scope is clear, create the ticket via the `jira` skill.
4. Transition the new ticket to "In Progress" via the `jira` skill.
5. Route directly to `modes/deep.md`. No classification.

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
- Exception: the [Pre-dispatch gate](#pre-dispatch-gate) translates the plan into prose for the user. The "do not expand" and `### Summary` rules do not apply there.

## Research before you lock in

Solutions are guesses. The difference between yours and the user's is shape, not certainty: they bring intuition and context, you bring breadth and search speed. Research is how either of you moves from guess to actual answer.

Before any plan or fix is final, look it up. Start by naming the question you'd most want a confident answer to — that's usually harder than it sounds, and it's where most of the value is. Then go find that answer. Wherever it lives — docs, release notes, a community thread, a blog post, the source — what matters is that you can say what you didn't know and now do.

Bring it back into the conversation with what you think it means. You pick from real options, together.

This is allowed to be curious. If a solution feels clean, that's interesting, not authoritative — clean solutions are sometimes right and sometimes training-data echoes. The research tells you which. The output you're aiming for is a solution you'd be proud of, not one you're defending.

## Pre-dispatch gate

The moment before workers dispatch is the user's highest-leverage decision point. Translate the plan into prose the user can act on without opening the plan file. Plain language. No internal vocabulary — no `O-1`, no "the controller", no template labels.

The chat brief is not the plan. The plan file is for workers and the `plan-review-agent` and can be 400 lines. The chat brief is for the user and tops out around 30 lines — past that the user rubber-stamps and the gate stops working.

### Small / medium tier — three beats

In order:

- **The problem** — what is broken or what the user can't do today. If a non-engineer in the room couldn't follow it, rewrite.
- **The fix** — concrete changes. Name files and what changes in each (`` `main.ts` — turn on raw-body mode ``). Name the test that proves it. If you made judgment calls while planning, fold them in here as "I chose X over Y because Z" — never as a separate jargon bullet.
- **Where we are** — one sentence: plan is written, nothing has changed yet, waiting on the user.

### Deep tier — five beats

A multi-task plan needs more redirect surface than three beats can carry. In order:

- **Why** — what the user can't do today. One sentence. Same standard as the small/medium "The problem".
- **Approach** — what we're building, 2-3 sentences. Names patterns and integration points, not files. (File-by-file detail lives in `plan.md`.)
- **Judgment calls — push back here** — 3-6 bullets, each one a decision a human might overrule (library choice, pattern, scope cut, deferral). Skip the mechanical or predetermined ones. This is the bullet list where the user actually steers.
- **Tasks** — one line per worker task, title only. No file lists, no steps, no code. Format: `T-N  short verb-led title`. Aim under 12 tasks; if more, regroup.
- **Risks** — 1-2 lines. The cross-cutting hazards a single worker can't see (shared-type churn, cascading prop changes, migration ordering).

Skip "Where we are" — at deep tier the user is technical and the binary ask carries that meaning implicitly.

### Both tiers

End with a binary ask: `go` to dispatch, anything else to hold. The two paths must be obvious; the user should not have to invent a third.

If `[NEEDS CLARIFICATION]` survives planning, surface it as one open question above the binary ask — do not bury it.

Do not append the progressive-format `### Summary` here — the gate is the summary.

The lead + binary-ask shape is also used at the first scoping message in deep mode (see [modes/deep.md](modes/deep.md)). Different binary ask (*agree on framing* vs. *go to dispatch*), same structure: context above the lead, decision at the bottom of the terminal where the cursor lands.

### What does NOT belong in chat

These live in `plan.md` and stay there:

- File inventories (paths the workers will touch)
- Numbered steps inside task cards
- Code snippets, type definitions, grep verifications
- The full QA Plan (link to it; do not paste)
- Outcomes formatted as `O-1` / `O-2` — translate to plain language

Reference the plan path (`.claude-artifacts/workflows/dev-workflow/plan.md`) so the user can open it. Never paste it.

### Examples

**Small tier — bug fix:**

> **The bug:** Clerk sends webhooks. The server checks they're real with a signature. Right now the check is broken — it's comparing the signature against a re-typed copy of the message instead of the original. Will fail in prod.
>
> **The fix:** One-line change in `main.ts` (turn on raw-body mode), one-line change in the webhook controller (`@Body` → `@RawBody`), plus a real test that signs a fake Clerk message and verifies it goes through.
>
> **Where we are:** I wrote the plan. Nothing has been changed yet. I'm waiting on you to say "go" before I dispatch a worker to do those three edits.
>
> Reply with "go" and I'll do it. Or "not now" and I'll stop.

**Deep tier — multi-task feature:**

> **KRAT-186 — Real data in 6 budgeting screens**
>
> **Why:** Paying customers see fake demo data on Accounts, Transactions, Categories, Overview, and Recurrings.
>
> **Approach:** Wire each screen to `/financial/*` via four new hooks (`useTransactions`, `useCategories`, `useOverview`, `useRecurrings`) and one new GET endpoint (`/financial/categories`). Mock-data files stay alive for the demo-mode ticket.
>
> **Judgment calls — push back here:**
>
> - Plain `useState` / `useEffect` hooks, NOT TanStack Query (matches `use-accounts.ts`)
> - All money in cents, format at the render boundary via a new `formatCents()` util
> - Net worth chart = "coming soon" placeholder (no historical balance data exists)
> - Mutations (review / edit) explicitly out of scope — read path only
>
> **Tasks (8):**
>
> ```
> T-0  formatCents util
> T-1  GET /financial/categories endpoint
> T-2  Delete duplicate types in shared/api/financial.ts + fix legacy callers
> T-3  4 new API clients + 4 new hooks
> T-4  Wire accounts-page.tsx
> T-5  Wire transactions-list-page.tsx
> T-6  Wire categories-page.tsx + CategoryBadge prop change
> T-7  Wire overview/dashboard-page.tsx + chart helpers
> T-8  Wire recurrings-page.tsx
> ```
>
> **Risks:** T-2 touches shared types — `pnpm build` from repo root will surface breaks. T-6's CategoryBadge prop change cascades to all callers (worker greps first).
>
> Plan: `.claude-artifacts/workflows/dev-workflow/plan.md`. Reply `go` to dispatch, or push back on any judgment call.

## Wrap-up

Every tier mode ends here before returning control.

1. Create PR via the `git-provider` skill.
2. Transition ticket to "in review" via the `jira` skill.
3. Run `code-review-agent` against the diff. If it returns findings, auto-fix what you can, commit as `address code review findings`, and push. One pass only.
4. Render the [Exit report](#exit-report) as the final message.

### Exit report

Mirror the plain-language voice of the [Pre-dispatch gate](#pre-dispatch-gate). No internal vocabulary (`O-1`, "the controller", "the spec"), no template labels, no diff-stat banner. Same shape across small, medium, and deep — only length varies.

Five beats, in order:

- **What this fixes** — the problem in the user's language, with one concrete example if it helps it land. If a non-engineer couldn't follow it, rewrite.
- **How it's fixed** — the mechanism, 1–3 sentences. Name a thing only when naming it is the clearest way to say what changed. No file roll-call, no per-outcome checklist.
- **Deviations from plan** — if any. Omit the heading if none.
- **How it was verified** — concrete evidence of the visible outcome beyond tests and build: rendered PDFs/images/screens read with the Read tool, UI flows driven end-to-end, scripts whose output you inspected. Default assumption: you can verify everything yourself except look-and-feel. Omit if tests and build are sufficient on their own.
- **What only you can verify** — look-and-feel only: visual taste, UX feel, copy. If `code-review-agent` flagged a user decision (scope cut, bundled commit), surface it here too. Omit the heading if none.

Build, tests, and a clean review pass are preconditions for being here. Do not list them. If something failed, fix it before exiting — that's not a report, it's a deviation.

End with `Run cleanup <TICKET> after merge.` then the PR URL on its own line.

### Exit report example

> **What this fixes:** Authenticated users could change other users' data by passing someone else's id in the URL (`/users/SOMEONE_ELSE/preferences`). Now they can only change their own.
>
> **How it's fixed:** Routes read identity from the authenticated session instead of the URL. The per-route ownership guard and the path parameter it policed are both gone. Frontend callers updated to match.
>
> **How it was verified:** Drove the login → settings-update flow against the dev server end-to-end; the unauthorized-id case now 403s where it previously succeeded.
>
> Run `cleanup KRAT-188` after merge.
>
> https://github.com/example/repo/pull/123

## Modes

- [modes/small.md](modes/small.md) — parent one-shots in the worktree
- [modes/medium.md](modes/medium.md) — plan, dispatch workers, parent review
- [modes/deep.md](modes/deep.md) — iterative scoping, QA planner, review gate, workers, parent review
- [modes/cleanup.md](modes/cleanup.md) — post-merge teardown

## What this skill does NOT do

- Auto-merge PRs
- Auto-classify tickets without user confirmation
- Poll PR state — `cleanup` is always user-initiated
- Run security review — invoke `security-expert-agent` manually when warranted
