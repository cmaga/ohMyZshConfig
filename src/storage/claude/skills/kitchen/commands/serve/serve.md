# Intake: turn a ticket into an order

A raw ticket is often a placeholder: stale, a duplicate, low value, or written wrong. Work enters only when the user types `take <KEY>`, and intake always runs with them, in the session where they typed it. Together you decide whether the ticket gets worked, its approach, its mode, and whether its PR waits for their review; then you write the order the working session follows. You write no code. Prefer no order over a guessed one: when anything you need is missing or uncertain, ask rather than guess. Talk to them only as [Talking to the user](#talking-to-the-user) says.

Every drop below (`status=86`) waits for the user's word: tell them what you found and write it once they agree.

1. **Load the order**: `kitchen.zsh order get <KEY>`. An `answer` from the user binds you: never drop the ticket for the reason they answered. When the order has a `last_session`, an earlier intake stopped short: read the last few entries of its transcript (`kitchen.zsh order transcript <KEY>` prints the path) for why, and when this skill's text caused it, address it per [SKILL.md](../../SKILL.md#defects-and-lessons).
2. **Read the whole ticket** with the `ticket-provider` skill: summary, description, every comment, links, status, assignee, and attachments. Capture the reporter's words, the expected and observed behavior, version and environment, frequency and trigger, error text, links to existing PRs or commits, and any statement that someone is already on it. Read screenshots and logs; when one cannot be read, say so rather than guess what it shows.
   - An open linked ticket blocks it, or its status says it is on hold: tell the user which, and stop. The order stays `new` until they take it again.
3. **Check nobody else holds it**: an assignee other than the user (`ticket.zsh holder <KEY>` prints `me`, `none`, or who), a remote branch named for it (`git ls-remote --heads origin | grep -iE '(^|[^A-Za-z0-9])<KEY>([^0-9]|$)'`), or an open PR named for it (the provider's open PR list through the `git-provider` skill, matched the same way). Someone does: tell the user who or what holds it, and on their word run `kitchen.zsh order set <KEY> status=86 reason=@<file>`, the file saying who or what holds it, and stop.
4. **Restate the intent**: the goal and the problem it solves, without the ticket's implementation nouns. Each one is a guess about the solution, to be checked against the code before you adopt it.
5. **Trace the cause before routing.** Run the [how](../cook/stations/how.md) station from the reported action to the observed result, and step 2 of the [why](../cook/stations/why.md) station, its code anchor, when it looks like a regression or touches defensive code. This pass is bounded: it needs no full root cause, only enough to route right.
   - The likely code path, and whether the symptom belongs to it or to something below it.
   - Recent changes on that path, and whether a merged commit or an open PR already addresses it.
   - Each factual claim the ticket makes (this crashes, that function does X, this field is missing) ends confirmed or refuted at `file:line` or by a run. Keep confirmed facts and hypotheses apart.
   - When the history shows an earlier attempt that was reverted, closed, or dropped, the intent says why this one differs.
6. **Dedupe.** Search open tickets through the `ticket-provider` skill by error text, area, trigger, and symptom. A confident duplicate (the same signature, or the same area, trigger, and symptom, or a confirmed shared cause): comment the link on both tickets, run `kitchen.zsh order set <KEY> status=86 "reason=duplicate of <OTHER>"`, and stop. A possible relation goes into the order's summary as uncertain. A long-closed match is a regression lead, not a duplicate.
7. **Decide which it is:**
   - **Stale**: already fixed, or no longer applies. Comment the evidence on the ticket, move it with the `merged` moment through the `ticket-provider` skill, run `kitchen.zsh order set <KEY> status=86 reason=@<file>`, and stop.
   - **Low value**: real, but not worth the time now. Leave the ticket open, comment why, run `kitchen.zsh order set <KEY> status=86 reason=@<file>`, and stop. The user can bring it back from `/kitchen status`.
   - **Written wrong**: the need is real but the ticket misstates it. Rewrite the description to match the code, comment what changed and why, and go on.
   - **Unclear**: bug or intended behavior, or what it should do, is a call no reading settles. Put that one call to the user now, with your recommendation, and carry on with their answer.
   - **Real**: go on.
8. **Pick the recipe**: the one from the list in [SKILL.md](../../SKILL.md#recipes) whose line fits the work, not the ticket's label. A ticket that bundles separable changes gets `multi-phase-plan`. None fits: `bespoke`, with the order's own `steps` designed per the [figure it out](../cook/stations/figure-it-out.md) station, each ending in a check and none waiting on the user: a step's measured result decides what comes next, and a call no measurement settles is put to the user now. They see the plan once, here. A `catering` pick ends intake early, since its approach is what its plan stage settles with the user, and it takes no done-when, mode, or review flag: in stage 3 below, send that it is catering and why in place of the approach. Once they agree, write the order with `kitchen.zsh order set <KEY> status=ready recipe=catering summary=@<file> intent=@<file>` and carry on in this session from [cook](../cook/cook.md#before-starting).
9. **Write the done-when.** Each line is a check that could fail: a command, a test, or a drive of the app that fails on the base branch today and passes once the order is done. "The settings page loads with no error, and errors today" qualifies; "works well" does not. A ticket filed from a multi-phase plan carries Verify blocks: they become the done-when as written.
10. **Set the mode and the review flag.** The `## Sorting` section of the project rules (`.claude/kitchen/house.md`) goes first and wins.
    - `mode`: recommend it per [mode](mode.md), and the user approves or changes it.
    - `review=true` when any done-when line is something only the user can judge: look and feel, wording users read, how a flow feels. A manual order always waits for the user whatever the flag says. What they agree to is recorded with `review=true` and its `review_why`. A PR is finished code with no question on it, so a call only the user can make is asked now, at intake, never left for the PR.
11. **Write the order** in one command. First write each text field to its own file with the Write tool, the list fields (`done_when`, `station`, `steps`) as JSON arrays. `station` lists the files and directories you expect the order to touch; the scheduler never runs two orders whose stations overlap.

        kitchen.zsh order set <KEY> status=ready recipe=<recipe> \
          mode=<manual|guided|auto> review=<true|false> review_why=@<file> \
          answer=@<file> summary=@<file> intent=@<file> done_when=@<file> \
          station=@<file> steps=@<file>

    `steps` only for `bespoke`; `review_why` only with `review=true`. `answer` holds what the user agreed to, the approach and the mode, which binds the working session. The summary carries the cause trace in a few lines, hypotheses labeled as such. Then tell them where the order waits: an `auto` order goes to the scheduler, which starts it on a pass when its files are free. A `manual` or `guided` order waits for `/kitchen next <mode>`, or for `take <KEY>` again, and nothing starts it until they do.

## Talking to the user

Intake runs in stages, one stage a message.

- A stage moves on only once the user says they follow it.
- Answer a question they ask inside the stage it comes up in. A question about why the system works as it does gets the code or vault line behind it.
- Write each stage in short paragraphs of plain prose: no bold labels over bullet lists, no file, table or function names, and no numbers until a stage needs them.
- Leave out the checks behind it, principles, and the calls you will make yourself.
- End each message with one question, whether they follow, and end your turn.

1. **The system**, once step 7 has sorted the ticket: what the part of the system the ticket is about is and what it does, for a reader who has never seen it. Nothing yet about what goes wrong.
2. **What fails**, once they follow the system: the moment it breaks, why, and what it costs, each measured number saying who measured it. A ticket steps 2 to 7 would hold or drop says why here and asks whether to.
3. **The recommendation**, once they follow the failure. Research how to solve it, run steps 8 to 10, then send the approach in a few sentences with its basis, and, when the approach changes something that exists, the option of keeping it. Add the mode line from [mode](mode.md) and a review line beside it: whether the PR waits for them, and why, always yes for a manual order. Discuss it until they agree on the approach, the mode, and the review.
4. **The order**, once they agree. Fold what you agreed into the files and write the order per step 11, then say where it waits and end.
