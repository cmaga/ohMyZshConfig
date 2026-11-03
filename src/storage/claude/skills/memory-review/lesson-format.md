# Skill lessons

How a session records friction with a skill while it still holds the evidence. Lessons live in auto memory under a `## Skill: <name>` section of `MEMORY.md`. They change nothing in the skill: `memory-review` reads them later and decides what changes.

## What counts

Two events, and nothing else:

- **You were corrected on process.** The user changed how the run works rather than what it builds — a step run in the wrong order, an instruction followed to a bad outcome, a rule they had to point at because you did not find it. Their correction is the event. Whether the skill is really at fault is the review's ruling, not yours.
  - A rule the skill already states and you did not apply counts too, once they correct you on it. A rule nobody applies at the moment it matters is a placement defect until review rules otherwise.
  - A slip you caught yourself, uncorrected by anyone, does not count.
- **The text underdetermined or misdirected what you did.** Nobody is in the room to correct you: you halted, escalated something the skill should have answered, found two rules pointing different ways and picked one, worked around an instruction that did not fit, or followed a rule as written to a bad outcome. It counts only when it changed what you did or how the run turned out.

None of these is a lesson: the code was hard, a test was flaky, a tool call was denied, the ticket was wrong, a subagent underperformed, or anything else the skill told you to expect. That is the work, not the skill.

## Writing one

- Write it the moment it happens, while you still hold why. Noticing late is never a reason to skip it.
- As a subagent, skip the rest of this list. Send the lesson to the main session with `SendMessage` to `main` — load the tool with `ToolSearch` (`select:SendMessage`) if it is deferred — starting the message with `Skill lesson for <name>:` and using the format below, then carry on. Only the main session files lessons; parallel writers to `MEMORY.md` lose each other's writes.
- Read the skill's section first. When a lesson there has the same cause, append today's date to its `Recurrences:` line instead of writing a second one.
- File a lesson that arrives by message exactly like your own.
- Filing a lesson happens in the middle of whatever you were doing: never something to discuss, escalate, or wait on, and never a reason to end a turn.

The topic file:

    ---
    name: move-by-transition-name
    description: Moved a ticket with its status name instead of its transition name
    metadata:
      type: feedback
    ---

    **Skill:** jira
    **File:** SKILL.md
    **Trigger:** correction
    **Date:** 2026-08-27
    **Run:** EN-326

    **What I did:** ran `jira issue move` with the target status name, "In Review".

    **What the text said:** setup stores transition names, but the move step never
    says which name it takes.

    **What it cost:** the move failed and the ticket stayed in To Do.

    **How to apply:** pass the stored transition name to `jira issue move`, never the status.

    **What would have helped:** one line in the move step naming `transitions.<moment>`.

    Recurrences:

Its `MEMORY.md` line, under the skill's section:

    ## Skill: jira
    - [Move by transition name](feedback_move_by_transition_name.md) — `jira issue move` takes the transition name, not the status

`Trigger` is `correction` or `underdetermined`. `Date` is the first sighting; each date on `Recurrences:` is another. `Run` names the ticket, or what you were doing when there is none. `File` names the skill file you were reading when it happened, `SKILL.md` for the entrypoint; `unknown` is a real answer and beats a guess. **How to apply** is what you do next time, and is what makes the lesson work before the skill changes. Drop **What would have helped** unless the answer is obvious — a guessed fix costs the reviewer more than no fix.
