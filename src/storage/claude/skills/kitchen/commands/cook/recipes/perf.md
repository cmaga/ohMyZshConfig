# Perf

A measured slowness to trace and improve against a baseline.

**You own the measurement story. Plan, review, verify the numbers.** Tie every fix to a measurement, don't read source instead of measuring.

1. Capture a baseline trace on the matching surface, through the project's verify skill (`.claude/skills/verify-*`), else the `run` skill. Commit the script that captures it, so the PR's numbers can be rerun. That script and its baseline are the contract: lock them per the [contract](../stations/contract.md) station, and no delegate edits them. Vet the baseline, and each later number, with the [benchmark checklist](../stations/benchmark-checklist.md) station.
2. Run the [how](../stations/how.md) station to ground hypotheses. Don't claim a perf ceiling without running it first.
   Try the performance mantras in order, cheapest first:
   1. Don't do it. Stop work whose result nothing uses rather than cheapening it.
   2. Do it, but don't do it again.
   3. Do it less.
   4. Do it later.
   5. Do it when they're not looking.
   6. Do it concurrently.
   7. Do it cheaper.

   When an earlier mantra meets the target, stop.
3. Plan the fix from the trace. If it crosses a function boundary, run the [architect](../stations/architect.md) station first. Delegate implementation to a `worker-agent` on the code role ([SKILL.md](../../../SKILL.md#subagents)). Review the diff. Capture a post-fix trace. Apply the [sequence verifiable units](../../../dependencies/principles/sequence-verifiable-units.md) principle, verifying each attempt before trying the next.
4. Parse and compare the artifacts (JSON to sqlite, diff). "Inconclusive" or wrong-surface is not a pass. Flag it.
5. Cite the measurement in the PR.
6. Run the [open a PR](open-a-pr.md) recipe.

For sustained improvement against a metric rather than a one-off fix, use the [hillclimb](hillclimb.md) recipe.

**Reply:** baseline number, post-fix number, delta, artifact path.
