# Skill lessons

How a session records friction with a skill while it still holds the evidence. Lessons live in auto memory under a `## Skill: <name>` section of `MEMORY.md`. They change nothing in the skill: `memory-review` reads them later and is the only thing that edits it.

## What counts

Two events, and nothing else:

- **You were corrected on process.** The user changed how the run works rather than what it builds — a step run in the wrong order, an instruction followed to a bad outcome, a rule they had to point at because you did not find it. Their correction is the event. Whether the skill is really at fault is the review's ruling, not yours.
  - A rule the skill already states and you did not apply counts too, once they correct you on it. A rule nobody applies at the moment it matters is a placement defect until review rules otherwise.
  - A slip you caught yourself, uncorrected by anyone, does not count.
- **The text underdetermined what you did.** Nobody is in the room to correct you: you halted, escalated something the skill should have answered, found two rules pointing different ways and picked one, or worked around an instruction that did not fit. It counts only when it changed what you did.

None of these is a lesson: the code was hard, a test was flaky, a tool call was denied, the ticket was wrong, a subagent underperformed, or anything else the skill told you to expect. That is the work, not the skill.

## Writing one

- Write it the moment it happens, while you still hold why. Noticing late is never a reason to skip it.
- As a subagent, skip the rest of this list. Send the lesson to the main session with `SendMessage` to `main` — load the tool with `ToolSearch` (`select:SendMessage`) if it is deferred — starting the message with `Skill lesson for <name>:` and using the format below, then carry on. Only the main session files lessons; parallel writers to `MEMORY.md` lose each other's writes.
- Read the skill's section first. When a lesson there has the same cause, append today's date to its `Recurrences:` line instead of writing a second one.
- File a lesson that arrives by message exactly like your own.
- Filing a lesson happens in the middle of whatever you were doing: never something to discuss, escalate, or wait on, and never a reason to end a turn.

The topic file:

    ---
    name: wave-opens-on-merge
    description: Opened a wave before its exclusive component merged
    metadata:
      type: feedback
    ---

    **Skill:** dev-workflow
    **File:** common/spec-run.md
    **Trigger:** correction
    **Date:** 2026-08-27
    **Run:** EN-326

    **What I did:** dispatched the wave before the exclusive component had merged.

    **What the text said:** step 3 says an exclusive component runs "first, in that
    wave's place" — it never says the siblings wait for it to merge rather than to
    start.

    **What it cost:** two managers rebased across the whole move.

    **How to apply:** open the next wave only once its exclusive component has merged.

    **What would have helped:** one line saying the wave opens on the merge.

    Recurrences:

Its `MEMORY.md` line, under the skill's section:

    ## Skill: dev-workflow
    - [Wave opens on merge](feedback_wave_opens_on_merge.md) — siblings wait for the exclusive component to merge, not start

`Trigger` is `correction` or `underdetermined`. `Date` is the first sighting; each date on `Recurrences:` is another. `Run` names the ticket, or what you were doing when there is none. `File` names the skill file you were reading when it happened, `SKILL.md` for the entrypoint; `unknown` is a real answer and beats a guess. **How to apply** is what you do next time, and is what makes the lesson work before the skill changes. Drop **What would have helped** unless the answer is obvious — a guessed fix costs the reviewer more than no fix.
