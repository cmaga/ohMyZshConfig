# Feature

New or changed behavior, built from a named data shape.

**You own the design. Plan, review, verify.** Delegate implementation. Stay in the lead.

1. Run the [how](../stations/how.md) station over the affected subsystem.
2. Run the [architect](../stations/architect.md) station's Phases A to C for parallel design exploration; its sketch is the scaffold the contract author commits in step 4.
   - A change that hinges on a third-party API's behavior or payload: fetch the provider's docs and read the existing integration code for that API.
   - New or changed UI: use the `frontend-design` skill, and carry its direction into the sketch so the delegate inherits it as structure, not prose.
3. Write the throughput checkpoint as four tasks in the task list. A dimension that genuinely does not apply (single file, no fan-out) keeps its task with `n/a: <reason>` rather than being dropped:
   - **Blocking first steps.** Gates run before fan-out.
   - **Independent workstreams.** Disjoint files, services, or layers parallelize. Shared writes serialize.
   - **Shared mutable state.** Default to splitting the target (the [separate before serializing shared state](../../../dependencies/principles/separate-before-serializing-shared-state.md) principle). Serialize only for real invariants.
   - **Smallest safe decomposition.** If one worker is best, name why.
4. Write and lock the tests per the [contract](../stations/contract.md) station, then read each against the intent.
5. Delegate code-writing to a `worker-agent` on the code role, or the hardest role for the hardest changes ([SKILL.md](../../../SKILL.md#subagents)), with a specific scope: the contract files and their `Contract-Run` command, never the done-when or how verify will drive the app, file paths, the named data shape and its organizing structure per the [model the domain](../../../dependencies/principles/model-the-domain.md) principle (a state machine over scattered booleans, a table or registry over branching, a typed model over repeated shape assumptions), chosen before the delegate writes logic, and success criteria. When the implementation admits multiple valid shapes (error handling, abstraction layer), delegate through the [arena](../stations/arena.md) station instead, so the runners surface the alternatives and the cross-judge guards the pick. This step is mandatory, with no skip-with-reason escape, and the [laziness protocol](../../../dependencies/principles/laziness-protocol.md) does not override it (the gain is review separation, not lines saved). Comments per [SKILL.md](../../../SKILL.md#comments). Surgical edits, re-ground against the source for upstream-derived files. Port shared-primitive improvements to all consumers and verify each. Commit liberally.
6. Verify the new behavior, and the existing behavior it must leave alone, on the matching surface, through the project's verify skill (`.claude/skills/verify*`), else the `run` skill. A contract or test run is not this step. A command-line change is verified by typing the command, in the session, against a tree the test made, and reading its output. "Inconclusive" or wrong-surface is not a pass. Flag it.
7. Rebase into small, ordered commits. Follow-ups go to [left for you](../stations/left-for-you.md). Use the [sequence verifiable units](../../../dependencies/principles/sequence-verifiable-units.md) principle, building, verifying, and committing each small unit before the next.
8. If the design is contested, run the [interrogate](../stations/interrogate.md) station before shipping.
9. Run the [open a PR](open-a-pr.md) recipe.

Code-coupled work (one feature, one migration) goes to a single owner with the checkpoint inline. Fan out within it only after its blocking phase. Fan out at the top level only for slices that produce independent artifacts (audits, cross-subsystem investigations, competing experiments). Rewrite the checkpoint at phase boundaries. Spawn a fresh owner rather than chaining interrupts.

**Reply:** what you built, what you chose and why, the throughput checkpoint, open decisions. Tables for design alternatives.
