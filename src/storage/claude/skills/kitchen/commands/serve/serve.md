# Intake: turn a ticket into an order

A raw ticket is often a placeholder: stale, a duplicate, low value, or written wrong. You decide whether it gets worked and, if so, write the order the working session follows. You write no code. Prefer no order over a guessed one: when anything you need is missing or uncertain, ask rather than guess.

The scheduler runs intake headless, and `cook` runs it with the user when they take a ticket intake has not seen. Headless, a ticket you cannot work is dropped (`status=86`), held, or put in the review queue for the user's call; it becomes an order only once nothing is left for them to decide. With the user here, talk to them only as [With the user here](#with-the-user-here) says.

1. **Load the order**: `kitchen.zsh order get <KEY>`. An `answer` from the user binds you: never drop it or send it back to the review queue for the reason they answered. When the order has a `last_session`, an earlier intake stopped short: read the last few entries of its transcript (`kitchen.zsh order transcript <KEY>` prints the path) for why, and when this skill's text caused it, address it per [SKILL.md](../../SKILL.md#defects-and-lessons).
2. **Read the whole ticket** with the `ticket-provider` skill: summary, description, every comment, links, status, assignee, and attachments. Capture the reporter's words, the expected and observed behavior, version and environment, frequency and trigger, error text, links to existing PRs or commits, and any statement that someone is already on it. Read screenshots and logs; when one cannot be read, say so rather than guess what it shows.
   - An open linked ticket blocks it, or its status says it is on hold: write why to a file, run `kitchen.zsh order hold <KEY> @<file>`, and stop. Intake tries it again later.
3. **Check nobody else holds it**: an assignee other than the user (`ticket.zsh holder <KEY>` prints `me`, `none`, or who), a remote branch named for it (`git ls-remote --heads origin | grep -iE '(^|[^A-Za-z0-9])<KEY>([^0-9]|$)'`), or an open PR named for it (the provider's open PR list through the `git-provider` skill, matched the same way). Someone does: `kitchen.zsh order set <KEY> status=86 reason=@<file>`, the file saying who or what holds it, and stop.
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
   - **Unclear**: bug or intended behavior, or what it should do, is a call no reading settles. It goes to the review queue, and the question is that one call.
   - **Real**: go on.
8. **Pick the recipe**: the one from the list in [SKILL.md](../../SKILL.md#recipes) whose line fits the work, not the ticket's label. A ticket that bundles separable changes gets `multi-phase-plan`. None fits: `bespoke`, with the order's own `steps` designed per the [figure it out](../cook/stations/figure-it-out.md) station, each ending in a check and none waiting on the user: a step's measured result decides what comes next, and a call no measurement settles goes in the sign-off question. Sign-off, so the user sees the plan once.
9. **Write the done-when.** Each line is a check that could fail: a command, a test, or a drive of the app that fails on the base branch today and passes once the order is done. "The settings page loads with no error, and errors today" qualifies; "works well" does not. A ticket filed from a multi-phase plan carries Verify blocks: they become the done-when as written.
10. **Set the two flags.** The `## Sorting` section of the project rules (`.claude/kitchen/house.md`) goes first and wins.
    - `review=true` when any done-when line is something only the user can judge: look and feel, wording users read, how a flow feels.
    - `signoff=true` when the work needs the user's call before it can be an order, as an unusual order goes to the head chef: whether to do it at all, how (a product decision, a choice between scopes, new structure other code will depend on), what to do instead, and how it will look to its users. An unclear ticket goes there too. A `catering`, `bespoke`, or `multi-phase-plan` order always does, so the user's answer covers its whole plan, and a `catering` order also needs review. The `question` puts each open call with your recommendation and what each answer would change. A call the PR can carry, such as whether to file a follow-up ticket, is not a sign-off: it goes to [Left for you](../cook/stations/left-for-you.md), which flags the PR for the user's review, and the work keeps going.
11. **Write the order** in one command. First write each text field to its own file with the Write tool, the list fields (`done_when`, `station`, `steps`) as JSON arrays. `station` lists the files and directories you expect the order to touch; the scheduler never runs two orders whose stations overlap.

        kitchen.zsh order set <KEY> status=<ready|review-queue> recipe=<recipe> \
          signoff=<true|false> review=<true|false> \
          summary=@<file> intent=@<file> done_when=@<file> station=@<file> \
          steps=@<file> question=@<file>

    `steps` only for `bespoke`. The summary carries the cause trace in a few lines, hypotheses labeled as such. Headless, `status` is `review-queue` with a `question` when `signoff=true`, else `ready`. With the user here, their agreement on the approach is the sign-off: write what they agreed to a file and pass `answer=@<file>` in place of `status` and `question`, so `cook` holds the order and carries on.

## With the user here

Each message carries only what the user needs for the decision in front of them, in plain words. Leave out the checks behind it, the order's flags, principles, and the calls you will make yourself. End your turn after each one.

1. **The problem**, once step 7 has sorted the ticket. Write it for a reader who has never seen this part of the system, under three bold labels with a few short lines each:
   - **How it works**: the parts involved and what each one does, one bullet per part, as an everyday picture rather than names from the code.
   - **What goes wrong**: the moment in that picture where it breaks, and what each part does wrong then.
   - **Why it matters**: what the user or the system sees as a result.

   A ticket steps 2 to 7 would hold or drop says why under the last label and asks whether to. Answer their questions until you both state the problem the same way.
2. **The recommendation**, once they agree on the problem. Research how to solve it, run steps 8 to 10, then send the approach in a few sentences with its basis. Discuss it until they agree.
3. **The goal line**, once they agree on the approach, and never before. Fold what you agreed into the files, write the order per step 11, and end the message with cook's [goal line](../cook/cook.md#the-goal-line). A `catering` order gets no goal line: carry on into [its recipe](../cook/recipes/catering.md), whose spec opens with a question to the user.
