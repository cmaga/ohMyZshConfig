# Wrap-up

Every tier ends here before returning control.

1. **Verify behavior** by driving the change in the real app via the `run` skill. If the change alters a shared interface, exercise each consumer flow. Skip only when the change has no runtime surface; state the reason. If verification needs a browser and the project has no Playwright MCP config — or a drive hits Chromium's profile lock — run `playwright-mcp-setup` first.
2. **Create the PR** via the `git-provider` skill. Skip on a spec-descended run: the branch is local and the whole spec goes up once.
3. **Transition the ticket** to "in review" via the `jira` skill.
4. **Run the review gate** — below. Skip on `small`, except unattended: there the gate is the only thing that reads the code.
5. **Wait on the PR's required checks** — unattended only. Red halts; the merge is the user's. A spec-descended run has no PR — see [Landing unattended](#landing-unattended).
6. **Render the [exit report](../templates/exit-report.md)**. Say the run is finished so the `/goal` evaluator can see it.
7. **Seed the [loose-end tracker](#the-loose-end-tracker)** and present its first item. That item, not the report, is the last thing on screen.

## The loose-end tracker

An open decision written as a sentence in a report reads as already taken. So anything still needing the user's judgment leaves as a task — one `TaskCreate` per item, appended below the run's own completed list.

### What qualifies

One test: **can you settle this by looking?** If yes, look, settle it, and it never reaches the user. What survives is three kinds:

- A **fix that genuinely could not ride the branch** — a discovered issue, or the review gate's **Tech debt** class.
- A review finding classed **Design** — never yours to fix.
- An **`[ASSUMED: ...]` that was a strategic call**, decided alone because the goal was armed.

Everything else fails: a finding you fixed, anything a ticket already owns, an `[ASSUMED]` settled by reading code, context with no decision attached. **If you cannot write the task as a question only the user can answer, it is not one.**

### Working it

One at a time: what it is, why it could not ride the branch, your recommendation — then stop. The user decides; dispatch a subagent to carry out the decision. **The user saying `next` advances the tracker.** Never auto-advance, never present two at once.

### The cap

**More than three tasks means the run deferred instead of finishing** — go back and fix the ones that could have ridden the branch. Zero is the common outcome: say in one line that there is nothing left to decide.

A component inside a [chain](spec-run.md) seeds nothing; its loose ends ride its report to the parent.

### Example

> **Concurrent venue probes on the trader's start floor — file it, or leave it?**
>
> This branch took the pre-READY floor past the 90s missed-heartbeat clock: three of the four bounded startup steps are venue probes, so one silent venue spends 3×30s. The fix is to run them under a single bound — a different subsystem's concurrency change, which is why it could not ride this diff.
>
> It costs nothing while the desk is dark and costs stopped quoting the moment anything is armed. No open ticket covers it — I searched. **I'd file it and link it to the arming ticket.**

## Review gate

Spawn `code-review-agent` once, fix what it finds, send the fixes back to **the same agent**. Repeat until it passes or escalates. It fans out on its own levers — pass it nothing about them. It returns JSON and never edits; you do all the fixing. A fresh reviewer re-reads everything, so keeping it alive is the whole efficiency of the loop.

### Count the rounds, in writing

**Open every dispatch with `Round N of the review gate.`** Keep a scratchpad file, one line per round: round number, reviewer agent id, commit reviewed, verdict, and the file and symbol of each confirmed bug. A restarted reviewer gets that file's contents — its escalate checklist reads the per-round symbols. Say the count in the exit report.

### What to pass it

- **Tell it to diff every stated claim against the mechanism that backs it.** Bounds, coverage figures, and every-X-is-handled sentences are where changes go wrong, always in the safe-looking direction.
- **First round** — what explains the change (the spec if one exists — a component sends its own `C-N` section and the ones its Needs names — else the scaffold commit and plan, else the ticket), the ticket, and the base branch if not `main`.
- **Later rounds** — `SendMessage` to the same agent: what you did about each finding and which commits hold the fixes. Never re-send the diff, the plan, or its own findings.
- **If that agent is gone** — spawn fresh with the first-round inputs, the round-count file, and what was done about last round's findings. Note the cold restart in the exit report.

### What comes back

Four kinds of finding. **Only bugs block the gate.**

| Kind          | What to do                                                                                           |
| ------------- | ---------------------------------------------------------------------------------------------------- |
| **Bug**       | Fix it, or propose a ticket when it is too big for this one.                                         |
| **Design**    | Never fix. A task on the [loose-end tracker](#the-loose-end-tracker).                                |
| **Quality**   | Fix it when it is small and provably behavior-preserving. Else list it.                              |
| **Tech debt** | A task on the [loose-end tracker](#the-loose-end-tracker) proposing a ticket, after the Jira search. |

`CONFIRMED` / `PLAUSIBLE` is confidence, not severity: verify a `PLAUSIBLE` bug yourself before acting when it would be serious if true.

### Fixing a bug

- **Read the whole path before editing.** A finding names a symptom and a line; the defect is often neither. Read every function on the path end to end, then edit from that reading.
- Apply the fix yourself. Never dispatch a worker for one.
- **Small enough** — apply, re-run the tests, commit as `address code review findings`, push unless spec-descended.
- **Too big** — a proposed ticket on the [loose-end tracker](#the-loose-end-tracker), after the Jira search. A proposal counts as handled.
- A recurring finding lists examples only; sweep the diff for the rest.
- **Sweep for the claim, not the symbol.** Everywhere that *quotes* the old behavior is stale, and a grep for the symbol will not find it — check the wiring module, the entry point, the README.

### When to stop

- **`"gate": "pass"`** — done.
- **`"gate": "escalate"`** — stop. Take its `reason` to the escalation agent in [Step 6](../SKILL.md#what-stops-attended), then the user; inside a chain, return it to the parent. Do not open another round to prove it wrong.
- **Five failed rounds** — advisory backstop. Say it fired in the exit report and carry on.

Whatever is still open becomes a task on the tracker with its disposition. A PR comment is not a disposition.

## Landing unattended

**A component inside a [chain](spec-run.md) does not land.** No PR, no push: committed work, a passed gate, and a green suite in its worktree is finished. It returns its exit report with the worktree still entered; the parent merges.

**A spec-descended unattended run that owns its own ticket** merges **locally** into the integration branch once the gate passes — no push, no PR — then goes straight to [cleanup](cleanup.md). Attended, it stops with the branch green and the user says when to merge.
