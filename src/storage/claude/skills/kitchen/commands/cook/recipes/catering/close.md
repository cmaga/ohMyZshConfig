# Close

Delivers the spec: every milestone has merged into `spec/<EPIC>`, and this order, cooked headless, checks the whole against the spec and opens the one PR to the base branch. The user reviews that PR and merges it themselves. After each step, run `kitchen.zsh order set <KEY> "step=close <n>"`.

1. **Take the branch**, when the order's `step` is empty; otherwise an earlier close session took it, so carry on after the step it names. `git fetch origin spec/<EPIC> <base>` (`<base>` is what `kitchen.zsh order base <KEY>` prints), `git reset --hard origin/spec/<EPIC>`, then rebase onto `origin/<base>`, resolving each conflict so both sides' intent survives. Then restate every milestone's contract in one empty contract commit (`git commit --allow-empty`), its trailers each milestone's latest `Contract-Files`, `Contract-Run`, and `Contract-Test` lines, per the [contract](../../stations/contract.md) station, so the contract check runs every milestone's tests.
2. **Read the whole spec against the branch.** Dispatch the reading to a `general-purpose` agent on the judgment role; it is the largest read in the work. Three checks only this scale can make:
   - **Census the spec**, not the plan: each `Owns` line and test scenario, asked of the branch. Then the plan's table of behavior in code the work deleted or rewrote: each row's fate, asked of the branch.
   - **Re-run any acceptance evidence that was stored rather than run.** A result older than the branch's tip is not a pass.
   - **Test the premise the spec opens with.** The problem the spec was written to kill belongs to no milestone's proof.
3. **Classify every deviation before repairing any.**
   - **Improvement**: keep the code and repair the spec.
   - **Regression**: fix the code, from the [contract](../../stations/contract.md) station on, as the [feature](../feature.md) recipe does from its step 4.
   - **Missing**: a gap the size of a part is not repaired here. Name it and what closing it takes; it goes on the order's Left for you list.
4. **Retire the planning artifacts.** Dispatch `vault-scribe-agent` to write one vault note per part from the final spec, attach the spec to the epic through the `ticket-provider` skill, and delete the spec from the repo on this branch.
5. **Open the PR** per the [open a PR](../open-a-pr.md) recipe, from step 1 through step 5, with `review=true "review_why=catering: delivers <EPIC>"`. In its body, `## What and why` says what the user can now do and `## Proof` lists each milestone's proof as what to try; record every deviation with its class through `kitchen.zsh decide`. Then `kitchen.zsh order verify <KEY>` for a verdict from a session that did not write it, and end. Run no merge recipe: the user reviews it per [the user's review](../merge.md#the-users-review).
