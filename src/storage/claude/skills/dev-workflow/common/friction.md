# Friction log

Where this skill's own defects get written down while the run that hit one is still holding the evidence. Nothing here changes the skill: entries are triaged later by `friction-review`, which is the only thing that edits anything.

Artifacts are user-lifecycle, type `workflows`: they outlive the worktree, the ticket, and the session on purpose, and only a review resolves them.

## What counts

Two events, and nothing else:

- **You were corrected on process.** The user changed how the run works rather than what it builds — a step run in the wrong order, an instruction followed to a bad outcome, a rule they had to point at because you did not find it. Their correction is the event. Do not also judge whether the skill is "really" at fault; that ruling belongs to a reader holding every other entry.

  **A rule you already had and did not apply is an entry too, once they correct you on it.** Whether it was findable where it sits is precisely what review decides, and a rule nobody applies at the moment it matters is a placement defect until someone rules otherwise. A run that writes the correction off as its own lapse is the run that keeps the defect alive.

  A slip you caught yourself, uncorrected by anyone, is not an entry. Their correction is what marks text that failed apart from a run that stumbled, and nothing else does.
- **The text underdetermined what you did.** Nobody is in the room to correct you: you halted, escalated something this skill should have answered, found two rules pointing different ways and picked one, or worked around an instruction that did not fit the situation.

The bar for the second is that it **changed what you did**. Ambiguity you noticed and sailed past is not an entry.

Text that anticipated what happened and told you what to do is not underdetermined, however surprising the event was. A refused call the skill predicts and routes around is the skill working, and logging it buries the entries that mean something.

None of these is an entry: the code was hard, a test was flaky, a tool call was denied, the ticket was wrong, a subagent underperformed, or anything else the text told you to expect. That is the work, not the workflow.

## Writing one

Write it the moment it happens, while you still hold why — an hour later the run remembers the correction and not the sentence that caused it.

Noticing late is never a reason to skip it. A moment you went past without recording is recorded as soon as you see it, and an entry written from what you still remember beats the entry nobody wrote.

One file per entry. A chain's managers run in parallel and a shared file loses writes.

    ~/.claude-artifacts/workflows/dev-workflow/friction/<TICKET>-<slug>.md

`<slug>` is three or four words naming the friction. `mkdir -p` the directory first. Write the file with the Write tool: a worktree-pinned run's Bash refuses command shapes it cannot trace, heredocs among them.

    ---
    ticket: EN-326
    date: 2026-08-27
    file: common/spec-run.md
    trigger: correction
    ---

    **What I did:** dispatched the wave before the exclusive component had merged.

    **What the text said:** step 3 says an exclusive component runs "first, in that
    wave's place" — it never says the siblings wait for it to merge rather than to
    start.

    **What it cost:** two managers rebased across the whole move.

    **What would have helped:** one line saying the wave opens on the merge.

`trigger` is `correction` or `underdetermined`. `file` names the skill file you were reading when it happened, `SKILL.md` for the entrypoint; `unknown` is a real answer and beats a guess, since review can find it and a wrong pointer sends it looking in the wrong place. Drop **What would have helped** unless the answer is obvious — a guessed fix costs the reviewer more than no fix.

Then carry on. An entry is one Write call in the middle of whatever you were doing: never something to report, discuss, escalate, or wait on, and never a reason to end a turn.
