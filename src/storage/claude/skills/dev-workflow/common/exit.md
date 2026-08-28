# Wrap-up

Every tier mode ends here before returning control.

1. **Verify behavior** by driving the change in the real app, via the `run` skill. If the change alters a shared interface, exercise each consumer flow, not just the changed surface. Skip only if the change has no runtime surface (pure refactor, types/docs, internal library); state the skip reason in chat. If verification needs a browser and the project has no Playwright MCP config — or a drive fails with Chromium's "browser is already in use" profile lock — run the `playwright-mcp-setup` skill first, then continue.
2. **Create the PR** via the `git-provider` skill. Skip it on a spec-descended run: that branch is local and unpushed, and the whole spec goes up as one pull request when it is complete.
3. **Transition the ticket** to "in review" via the `jira` skill.
4. **Run the review gate** — see below. Skip on `small`, except under auto: `small` has no scaffold and no tests, so the gate is the only thing that reads the code before it merges.
5. **Land it** — auto only, see [Landing under auto](#landing-under-auto).
6. **Disarm the auto guard** — auto only, and never a component inside a chain: it armed none, and the chain disarms its own at the end. `~/.claude/hooks/auto-run-guard.sh end <TICKET>`. The report that follows is prose alone, so this is the last tool call of the run.
7. **Render the [exit report](../templates/exit-report.md)** as the final message.

## Review gate

Spawn `code-review-agent` once, fix what it finds, then send the fixes back to **the same agent**. Repeat until it passes or escalates. **Tell it to spawn nothing** — a reviewer that fans out loses every finding its helpers return and reports a verdict over the ground it covered itself. If a review needs several perspectives, run those agents yourself.

Keeping it alive is the whole efficiency of this loop. A fresh reviewer re-reads the spec, the diff, and the full source of every changed file before it can say anything — that reload is the cost of a round, not the reviewing. The agent you already have holds all of it, plus its own reasoning for every finding it raised.

It returns JSON and never edits files. You do all the fixing.

### What to pass it

- **Tell it to diff every stated claim against the mechanism that backs it.** Bounds, coverage figures and every-X-is-handled sentences are where changes on this workflow go wrong, and never as a logic error: a guard that checks thirteen of fourteen, an anti-vacuity floor one quantifier weaker than its own sentence, a worst-case number stated three times and wrong twice. Always in the safe-looking direction, and in one run three of the six were inside artifacts written to prevent exactly that.
- **First round** — what explains why the change was made (the spec if one exists — a component run sends its own `C-N` section and the ones its Needs names, not the whole document — else the scaffold commit and the plan, else the ticket title and description), the ticket, and the base branch if it is not `main`.
- **Later rounds** — continue the same agent with `SendMessage`. Send only what it does not already have: what you did about each finding, and which commits hold the fixes. Never re-send the diff, the plan, or its own findings.
- **If that agent is gone** (compaction, a dead agent) — spawn a fresh one with the first-round inputs plus last round's findings and what was done about each, and note in the exit report that the reviewer restarted cold.

### What comes back

Four kinds of finding. **Only bugs block the gate.**

| Kind          | What to do                                                                                             |
| ------------- | ------------------------------------------------------------------------------------------------------ |
| **Bug**       | Fix it, or propose a ticket when it is too big for this one. See below.                                |
| **Design**    | Never fix. List it in the exit report — it is the user's call.                                         |
| **Quality**   | Fix it when it is small and provably behavior-preserving (dead code, a misleading name). Else list it. |
| **Tech debt** | List it in the exit report as a proposed ticket, with the Jira search showing none exists.             |

Bugs carry a `CONFIRMED` or `PLAUSIBLE` tag. That is confidence, not severity: it decides whether you verify before fixing, never whether it gets fixed. Verify a `PLAUSIBLE` bug yourself before acting when it would be serious if true — uncertainty is a reason to check, not to skip.

### Fixing a bug

- **Read the whole path before editing.** A finding names a symptom and a line; the defect is often neither. Locate it yourself, then read every function on that path end to end — the writer sitting below the reader you are adding, the second consumer of the condition you are narrowing, every caller that reaches the early return you are inserting. Edit from that reading, never by pattern-replacing text you have not read.
- Apply the fix yourself. Never dispatch a worker for one — the reading that prevents the next regression does not survive the handoff.
- **Small enough for this ticket** — apply it, re-run the tests, commit as `address code review findings`, and push unless the run is spec-descended, whose branch is local.
- **Too big** — carry it into the exit report as a proposed ticket, searching Jira first per the discovered-issue rule in [SKILL.md](../SKILL.md). A proposal counts as handled for the gate; do not file it to unblock yourself.
- A recurring finding lists example locations only. Sweep the diff for the rest when you apply the fix.
- **Sweep for the claim, not the symbol.** When a behaviour changes, everywhere that *quotes* the old behaviour is now stale, and a grep for the function's name will not find them. Check the definitional surface explicitly — the wiring module, the entry point, the README — because it describes the thing in one prose line and matches no name-based sweep, which is why it is the instance that survives four rounds of correction. It is also the file someone opens to learn what the job does, so the stale sentence there is the one that gets believed.

### When to stop

- **`"gate": "pass"`** — done.
- **`"gate": "escalate"`** — stop. The reviewer has decided the loop will not converge and its `reason` says what it thinks is wrong underneath. Take that to the user — or, inside a chain, return it to the parent, which decides. Either way, do not open another round to prove it wrong.
- **Five failed rounds** — a backstop for when the reviewer does not make that call itself. It should almost never fire; when it does, say so in the exit report.

Whatever is still open goes in the exit report rather than into another round.

Every finding you did not fix appears there with its disposition — an existing ticket's key, or a proposed one for the user's call. A PR comment is not a disposition: the PR closes and it is orphaned.

## Landing under auto

**A component running inside a [chain](auto-chain.md) does not land.** It opens no pull request and pushes nothing: committed work on its own branch, a passed review gate and a green full suite in its worktree are the chain's definition of a finished component. It returns its exit report with the worktree still entered; the chain parent merges, cleans up, and will send it back in to rebase. Nothing below runs.

**A spec-descended auto run that owns its own ticket does the merge and the cleanup, and neither of the deploy steps.** It merges **locally** into the spec's integration branch — no push and no pull request, since the whole spec goes up as one PR when it is complete — then leaves the worktree and goes straight to [cleanup](cleanup.md). Attended, it stops with the branch built and green and the user says when to merge. Deploying would ship a base branch that does not contain the change, and verifying live would check behavior that is not there; the spec deploys as one release, once the user merges the integration branch.

Only once the gate passes, in this order. Anything that fails halts the run and hands back with the PR and the worktree left standing — they are the evidence. Disarm the guard before handing back; a halt is a hand-back.

1. **Merge** via the `git-provider` skill. Wait on the PR's required checks first; red, or never going green, halts. A spec-descended run merges its own branch into the integration branch with git instead — there is no PR and no checks to wait on, and the suite it already ran is the bar.
2. **Leave the worktree.** `ExitWorktree` with `action: "keep"` — `action` is required, and `keep` leaves the worktree standing as evidence for steps 3 and 4; step 5 removes it. Exiting is what unpins the session: until it returns, git targets the worktree only and the main checkout is unreachable. Then pull the base branch in the main checkout under the main-checkout gate (Prerequisites, [SKILL.md](../SKILL.md)).
3. **Deploy.** Read `<project-root>/.claude/skills/dev-workflow/config.json` ([template](../dependencies/templates/dev-workflow-config.json)) and run its `deploy`, then poll `healthCheck` until it passes. No file, or no `deploy` in it, means this project is deployed by hand: skip to step 5 and say so in the report.
4. **Verify what is live** — step 1's behavior check again, run against `verifyTarget` instead of the local app. This is the only proof the merge did what the tests said.
5. **[Cleanup](cleanup.md)** the ticket: it moves to done, the worktree and branch go away.
