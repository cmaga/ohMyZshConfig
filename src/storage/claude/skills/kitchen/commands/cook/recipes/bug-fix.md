# Bug fix

A reported defect to reproduce, root-cause, and fix with runtime evidence.

**You own this task. Plan, review, verify.** Delegate investigation and the fix to subagents, and stay in the lead. Each subagent takes its role from [SKILL.md](../../../SKILL.md#subagents).

Be scientific. Every shipped line traces to runtime evidence. Belt-and-suspenders that "might help" is a hypothesis, not a fix. It does not ship. When evidence refutes a hypothesis, revert what it motivated. The smallest change the evidence justifies ships, nothing more.

1. Reproduce it yourself on the matching surface, through the project's verify skill (`.claude/skills/verify-*`), else the `run` skill, even when a debug or instrumentation protocol says to ask the user to reproduce. Hand it to the user only with a stated, specific reason the verify skill cannot reach the target, and only after driving it as far as it goes. Headless, that hand-off is `kitchen.zsh order withdraw <KEY> @<file>`, the file saying why and how far the drive got. If it won't reproduce directly, synthesize the trigger, tighten conditions, or instrument until it fires. With an order, add the repro to its `done_when`, where it stays as the regression check: write the current list plus the repro to a file and run `kitchen.zsh order set <KEY> done_when=@<file>`.
2. Binary-search the cause. Form the candidate hypotheses, then rule them out until one survives. Seed them with the [how](../stations/how.md) station over the affected subsystem and the [why](../stations/why.md) station for regression history. Each pass, take the split that cuts the most remaining problem space, get runtime evidence, eliminate. When program state is unclear, add instrumentation or logging and read it as the code runs. Don't guess. With the user here, drive a long or stubborn hunt with `/loop`. Confirm the surviving *mechanism* with runtime evidence before the step 3 architect or interrogate fan-out.
   - A bug that hinges on a third-party API's behavior or payload: fetch the provider's docs and read the existing integration code for that API.
3. Plan the fix. If it crosses a function boundary, run the [architect](../stations/architect.md) station's Phases A to C first. Lock the repro as the test per the [contract](../stations/contract.md) station, then delegate implementation to a `worker-agent` on the code role with a specific scope that carries the contract files and their `Contract-Run` command. A fix that changes UI uses the `frontend-design` skill.
4. Verify on the same surface. The original repro now passes. "Inconclusive" or wrong-surface is not a pass. Flag it. Unit tests show branch behavior, not bug absence.
5. Stage the commits so the failing repro, the contract commit, lands before the fix in git history. This is the canonical case of the [sequence verifiable units](../../../dependencies/principles/sequence-verifiable-units.md) principle, the failing test first and the fix on top.
6. Run the [open a PR](open-a-pr.md) recipe.

**Reply:** what was broken, root cause, fix, how you verified. Paste failing-then-passing repro output verbatim.
