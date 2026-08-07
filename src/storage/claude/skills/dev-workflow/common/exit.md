# Wrap-up

Every tier mode ends here before returning control.

1. **Verify behavior** via the `verify` skill. If the change alters a shared interface, exercise each consumer flow, not just the changed surface. Skip only if the change has no runtime surface (pure refactor, types/docs, internal library); state the skip reason in chat. If verification needs a browser and the project has no Playwright MCP config — or a drive fails with Chromium's "browser is already in use" profile lock — run the `playwright-mcp-setup` skill first, then continue.
2. **Create the PR** via the `git-provider` skill.
3. **Transition the ticket** to "in review" via the `jira` skill.
4. **Run the review gate** — see below. Skip on `small`.
5. **Render the [exit report](../templates/exit-report.md)** as the final message.

## Review gate

Spawn `code-review-agent` once, fix what it finds, then send the fixes back to **the same agent**. Repeat until it passes or escalates.

Keeping it alive is the whole efficiency of this loop. A fresh reviewer re-reads the spec, the diff, and the full source of every changed file before it can say anything — that reload is the cost of a round, not the reviewing. The agent you already have holds all of it, plus its own reasoning for every finding it raised.

It returns JSON and never edits files. You do all the fixing.

### What to pass it

- **First round** — what explains why the change was made (the spec if one exists, else the scaffold commit and the plan, else the ticket title and description), the ticket, and the base branch if it is not `main`.
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
- **Small enough for this ticket** — apply it, re-run the tests, commit as `address code review findings`, push.
- **Too big** — carry it into the exit report as a proposed ticket, searching Jira first per the discovered-issue rule in [SKILL.md](../SKILL.md). A proposal counts as handled for the gate; do not file it to unblock yourself.
- A recurring finding lists example locations only. Sweep the diff for the rest when you apply the fix.

### When to stop

- **`"gate": "pass"`** — done.
- **`"gate": "escalate"`** — stop. The reviewer has decided the loop will not converge and its `reason` says what it thinks is wrong underneath. Take that to the user; do not open another round to prove it wrong.
- **Five failed rounds** — a backstop for when the reviewer does not make that call itself. It should almost never fire; when it does, say so in the exit report.

Whatever is still open goes in the exit report rather than into another round.

Every finding you did not fix appears there with its disposition — an existing ticket's key, or a proposed one for the user's call. A PR comment is not a disposition: the PR closes and it is orphaned.
