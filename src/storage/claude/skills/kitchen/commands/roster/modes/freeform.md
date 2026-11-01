# Freeform Mode

Invoked with context: a new model, a pricing change, a workload shift, a hunch to evaluate.

1. **Frame it.** Restate the user's context as a question the levers can answer (e.g. "does Sonnet 6 displace Opus for workers?" or "does the new pricing change the daily-driver call?").
2. **Research the context only.** Web docs and the `claude-api` skill for whatever the context introduces (new model capabilities, new pricing). Judge against [levers.md](../references/levers.md) and [lever-impact.md](../references/lever-impact.md) as they stand — no re-measuring; calibration belongs to [refresh-levers](refresh-levers.md).
3. **Recommend.** A judgment call mapped onto the lever table: which settings change and why. Give a recommendation, not a survey.
4. **Gate and apply** as Default mode steps 4-5. If the research invalidated the table itself (new model, changed prices), fold a [refresh-levers](refresh-levers.md) pass into the same approval.
