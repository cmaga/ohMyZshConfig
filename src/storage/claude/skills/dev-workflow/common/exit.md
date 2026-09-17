# Wrap-up

Every tier mode ends here before returning control.

1. **Verify behavior** by driving the change in the real app, via the `run` skill. If the change alters a shared interface, exercise each consumer flow, not just the changed surface. Skip only if the change has no runtime surface (pure refactor, types/docs, internal library); state the skip reason in chat. If verification needs a browser and the project has no Playwright MCP config — or a drive fails with Chromium's "browser is already in use" profile lock — run the `playwright-mcp-setup` skill first, then continue.
2. **Create the PR** via the `git-provider` skill. Skip it on a spec-descended run: that branch is local and unpushed, and the whole spec goes up as one pull request when it is complete.
3. **Transition the ticket** to "in review" via the `jira` skill.
4. **Run the review gate** — see below. Skip on `small`, except unattended: `small` has no scaffold and no tests, so the gate is the only thing that reads the code before it merges.
5. **Wait on the PR's required checks** — unattended only. Red, or never going green, halts; the merge and the deploy are the user's. A spec-descended run has no PR — see [Landing unattended](#landing-unattended).
6. **Render the [exit report](../templates/exit-report.md)**. The `/goal` the user armed is theirs to clear; say in the report that the run is finished so its evaluator can see the condition met.
7. **Seed the [loose-end tracker](#the-loose-end-tracker)** and present its first item. That item, not the report, is the last thing on screen.

## The loose-end tracker

The report is prose, and prose narrates. It lands in a scrollback of agent returns and tool output, gets skimmed, and an open decision written as a sentence reads as a decision already taken — *"a deadline, not a ticket; it's recorded on the note that owns the clock"* is a real one that sailed past a user who was reading. A task cannot do that. It is open or it is closed.

So anything still needing the user's judgment leaves as a task, never as a line in the report. Seed one `TaskCreate` per item — the tools are already loaded from Prerequisite 1, and the run's own step list is completed by now, so these append below it as the only open work.

### What qualifies

One test: **can you settle this by looking?** If yes, look, settle it, and it never reaches the user. Does a ticket already own it — search. Is it still engaged — probe the box. Is it deployed, is the branch merged, does that symbol still exist — check. A question you could have answered yourself spends the user's attention on nothing, and they notice.

What survives that test is three kinds, and no others:

- A **fix that genuinely could not ride the branch** — a discovered issue, or the review gate's **Tech debt** class. The fix is real; the decision is whether to own it now. It has already passed the [discovered-issue rule](../SKILL.md)'s bar, so what reaches the tracker is the residue of a rule that already said fix it.
- A review finding classed **Design** — the gate already ruled these are never yours to fix.
- An **`[ASSUMED: ...]` that was a strategic call** — the kind an attended run would have escalated, decided alone because the goal was armed. The run decided; the user may want it back.

Everything else fails the test. A quality finding you fixed, anything already owned by a ticket key, and above all **an `[ASSUMED]` you settled by reading the code** — that last one is most of them, and the reading is what disqualifies it. Context does not qualify either: a fact with no decision attached is not an item, however interesting, and padding the list with one buries the item that is real. **If you cannot write the task as a question only the user can answer, it is not one.**

### Working it

One at a time. Present the item in a few lines — what it is, why it could not ride the branch, and your recommendation — then stop. The user decides. **Dispatch a subagent to carry out the decision**, whatever it is: filing the ticket, making the change, opening the follow-up.

**The user saying `next` is what advances the tracker.** Mark that task `completed` and present the following one. Never auto-advance, never present two at once, and never mark one completed because you think it is settled — the word is theirs.

### The cap

**More than three tasks means the run deferred instead of finishing.** Go back and fix the ones that could have ridden the branch before seeding anything. It is the [discovered-issue rule](../SKILL.md)'s own bar, and it binds harder here: a paragraph can carry three deferrals and still read as thorough, where three open tasks read as what they are.

Zero is the good outcome and the common one. Then seed nothing, say in one line that there is nothing left to decide, and stop.

A component inside a [chain](spec-run.md) seeds nothing either — its reader is the chain parent, which is not a user and cannot decide anything. Its loose ends ride its report to the parent, which collapses them into its own tracker at the end of the chain.

### Example

One task, and what presenting it looks like:

> **Concurrent venue probes on the trader's start floor — file it, or leave it?**
>
> This branch took the pre-READY floor past the 90s missed-heartbeat clock: three of the four bounded startup steps are venue probes, so one silent venue spends 3×30s. The fix is to run them under a single bound — a different subsystem's concurrency change, which is why it could not ride this diff.
>
> It costs nothing while the desk is dark and costs stopped quoting the moment anything is armed. No open ticket covers it — I searched. **I'd file it and link it to the arming ticket.**

The user answers, a subagent files it, and the tracker moves on the word `next`.

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
| **Design**    | Never fix. It becomes a task on the [loose-end tracker](#the-loose-end-tracker) — it is the user's call.                |
| **Quality**   | Fix it when it is small and provably behavior-preserving (dead code, a misleading name). Else list it. |
| **Tech debt** | A task on the [loose-end tracker](#the-loose-end-tracker) proposing a ticket, with the Jira search showing none exists. |

Bugs carry a `CONFIRMED` or `PLAUSIBLE` tag. That is confidence, not severity: it decides whether you verify before fixing, never whether it gets fixed. Verify a `PLAUSIBLE` bug yourself before acting when it would be serious if true — uncertainty is a reason to check, not to skip.

### Fixing a bug

- **Read the whole path before editing.** A finding names a symptom and a line; the defect is often neither. Locate it yourself, then read every function on that path end to end — the writer sitting below the reader you are adding, the second consumer of the condition you are narrowing, every caller that reaches the early return you are inserting. Edit from that reading, never by pattern-replacing text you have not read.
- Apply the fix yourself. Never dispatch a worker for one — the reading that prevents the next regression does not survive the handoff.
- **Small enough for this ticket** — apply it, re-run the tests, commit as `address code review findings`, and push unless the run is spec-descended, whose branch is local.
- **Too big** — carry it to the [loose-end tracker](#the-loose-end-tracker) as a proposed ticket, searching Jira first per the discovered-issue rule in [SKILL.md](../SKILL.md). A proposal counts as handled for the gate; do not file it to unblock yourself.
- A recurring finding lists example locations only. Sweep the diff for the rest when you apply the fix.
- **Sweep for the claim, not the symbol.** When a behaviour changes, everywhere that *quotes* the old behaviour is now stale, and a grep for the function's name will not find them. Check the definitional surface explicitly — the wiring module, the entry point, the README — because it describes the thing in one prose line and matches no name-based sweep, which is why it is the instance that survives four rounds of correction. It is also the file someone opens to learn what the job does, so the stale sentence there is the one that gets believed.

### When to stop

- **`"gate": "pass"`** — done.
- **`"gate": "escalate"`** — stop. The reviewer has decided the loop will not converge and its `reason` says what it thinks is wrong underneath. Take that to the escalation agent in [Step 6](../SKILL.md#what-stops-attended), and to the user only if it cannot decide — or, inside a chain, return it to the parent, which decides. Either way, do not open another round to prove it wrong.
- **Five failed rounds** — a backstop for when the reviewer does not make that call itself. It should almost never fire; when it does, say so in the exit report.

Whatever is still open becomes a task on the [loose-end tracker](#the-loose-end-tracker) rather than another round.

Every finding you did not fix appears there with its disposition — an existing ticket's key, or a proposed one for the user's call. A PR comment is not a disposition: the PR closes and it is orphaned.

## Landing unattended

**A component running inside a [chain](spec-run.md) does not land.** It opens no pull request and pushes nothing: committed work on its own branch, a passed review gate and a green full suite in its worktree are the chain's definition of a finished component. It returns its exit report with the worktree still entered; the chain parent merges, cleans up, and will send it back in to rebase.

**A spec-descended unattended run that owns its own ticket does the merge and the cleanup.** Once the review gate passes, it merges **locally** into the spec's integration branch with git — no push, no pull request and no checks to wait on, since the whole spec goes up as one PR when it is complete and the suite it already ran is the bar — then goes straight to [cleanup](cleanup.md). Attended, it stops with the branch built and green and the user says when to merge.
