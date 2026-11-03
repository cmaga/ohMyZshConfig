# Autonomous run

A long task to drive to completion without stopping ("run until done", "/loop until X").

**You own the exit condition. Define done, then drive to it without stopping.**

1. State the exit condition as a checkable predicate before the first iteration (tests green, repro fixed, all N PRs merged, pixel-diff zero).
2. Pick the wake mechanism. An event to watch (CI, a merge, a ref advancing) gets a background watcher that wakes you on the event, such as `gh pr checks <url> --watch` run in the background, which notifies you when it exits, with a long time-based heartbeat as fallback. No event gets a fixed-interval heartbeat sized to when the result is worth re-checking. With the user here, run the loop under `/loop`. Headless, there is no `/loop`: the watcher is the wake, and the scheduler starts a new session when the order's PR changes. Each subagent takes its role from [SKILL.md](../../../SKILL.md#subagents).
3. Each iteration makes the smallest change the evidence justifies, verifies it against the predicate, commits if it advanced, discards changes that didn't help. Belt-and-suspenders that "might help" gets reverted, not left to ride. Sequence the work via the [sequence verifiable units](../../../dependencies/principles/sequence-verifiable-units.md) principle, verifying each unit before the next instead of batching checks at the end.
4. Mid-run discoveries that support the goal are yours. Address broken skills, related bugs, flaky verifiers, review noise, tooling failures, orphaned follow-ups, and fixable drift yourself per [SKILL.md](../../../SKILL.md). Address a kitchen defect per [SKILL.md](../../../SKILL.md#defects-and-lessons); put other out-of-band fixes in their own PR. Do not park reversible work for the user or ask them about it. Surface only irreversible actions, genuine product or preference calls no experiment can settle, or a real dead end. Keep the predicate as the main drive, and return to it after each side fix.
5. Checkpoint every iteration via the [show me your work](../stations/show-me-your-work.md) station, a row for what changed and whether the predicate moved.
6. Stop when the predicate is met. A plateau is not a stop, so keep going and pivot your approach to push past it. Surface a genuine dead end rather than spinning, and never relax the predicate to declare victory.

**Reply:** the exit condition, iterations run, what landed, what was discarded, final predicate state.
