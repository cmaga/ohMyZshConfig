# Deployment

One deployment of a catering order: its skeleton with the user, its phases in the order's mode, the check of the whole, and one PR that waits for the user. The order carries `catering` (the epic), `docs`, `deployment` (its number), and `stage`. It follows this file in place of its recipe's steps, after [cook](../../cook.md) steps 5 to 7 and 9 (its worktree, a pickup, an existing PR, the ticket). Before the first step, read its section of `<docs>/implementation-plan.md`, every DEC its tasks cite, and the spec's sections for the parts on its Touches line, and hold the code to them.

## The skeleton

At `stage=skeleton` the user is here: only they start a deployment at this stage, and its mode stays as filed.

1. **Research the standards.** Per the [look it up](../../../../dependencies/principles/look-it-up.md) principle, the standard patterns for this stack and kind of feature, from current docs and practice, with sources; per the [how](../../stations/how.md) station, the patterns the project already uses where the deployment joins it. Present them one point at a time, per [catering](../catering.md#talking-to-the-user): the pattern, why it is the standard, and what it means for this skeleton. Where the project's pattern and the standard differ, the user picks.
2. **Draft the skeleton** per the [architect](../../stations/architect.md) station's sketch, at the paths in the skeleton task's Files: the modules, types, signatures, and stubs whose bodies are not implemented and whose docstrings state the behavior, holding every contract its Produces line names. Then the [contract](../../stations/contract.md) station writes the tests for the spec tests this deployment owes, briefed with the skeleton and the deployment's mode.
3. **Refine it with the user** until they approve it. A change to a contract rewrites its DEC in the implementation plan, and every task that cites it.
4. **Commit it** as phase 1 per the contract station, a contract commit unless the deployment is `manual`, then `kitchen.zsh order set <KEY> stage=build "step=phase 1 Skeleton"`.
5. **Hand on by mode.**
   - `auto`: `kitchen.zsh order set <KEY> status=ready pid=0`. Say the scheduler builds the rest and the PR comes back for their review, and end.
   - `guided`: hand the [goal line](../../cook.md#the-goal-line), and carry on with [The phases](#the-phases).
   - `manual`: go the [manual way](../../cook.md#a-manual-order) from its step 2, with the skeleton tests' run command as its test command, and work per [Manual phases](#manual-phases).

## The phases

For each phase from 2, in order:

1. **Dispatch** one fresh `worker-agent` on the code role per task, after noting the branch's tip as the phase's start. A one-task phase works in this worktree; in a fan-out each worker gets `isolation: "worktree"`, its brief naming that tip to check out first, as the [swarm](../../stations/swarm.md) station does. Each brief carries the order's intent, the task's section verbatim, the contract of every DEC it cites, its Files as the only files it may change, the locked tests it must turn green (the coverage rows that name it), and that it challenges a test it believes wrong in its report instead of editing it.
2. **Hold each task to its scope.** Its diff touches only its Files, and `bash ~/.claude/skills/kitchen/dependencies/scripts/contract-check.sh origin/<base>` reports the contract intact. Revert what falls outside and hand it to a fresh worker with the reason. Merge each fan-out worker's branch here.
3. **Gate the phase.** Run the `Gate` command from the project rules on the merged result. Then a `general-purpose` agent on the judgment role, which wrote none of the phase, reads the phase's diff against the DECs its tasks cite, their spec sections, and the skeleton's pattern, and reports each departure. A fresh worker fixes each finding before the next phase. None of the gate's output goes in the PR.
4. **Commit the phase once**: `git reset --soft <the phase's start>`, then one commit whose subject is the deployment's title and `(phase <n>: <name>)`. Then `kitchen.zsh order set <KEY> "step=phase <n> <name>"`.

**A better route** that a worker or the gate turns up rewrites the plan at once: the DECs and later tasks it changes, here and in later deployments (`kitchen.zsh order set <LATER> done_when=@<file> station=@<file>`, and its ticket through the `ticket-provider` skill), and the spec when behavior changes. Log it with `kitchen.zsh decide`. With the user here, a design question it raises is discussed then; headless, one that overturns what the user decided goes per [Autonomy](../../../../SKILL.md#autonomy).

## Manual phases

The user writes the bodies in VS Code, phase by phase, and may change the skeleton's tests and calls as they see fit, per the [contract](../../stations/contract.md#a-manual-order) station. When they say "check", read the diff since the last check against the phase's tasks, the DECs they cite, and the skeleton's pattern, and answer one of three: as planned; different and better, and why; or different and worse, why, and what the plan had. A better route rewrites the plan at once, as above, and a design question it raises is discussed then. At the end of each phase, run step 3's gate and report its findings to the user, who fixes them; commit the phase on their word, as step 4 does. When they say "done" after the last phase, go on at [Ready for review](#ready-for-review).

## Ready for review

1. **Check the whole.** Every coverage row this deployment's tasks owe is delivered by its code and a passing test, per the [done-when](../../../taste/done-when.md) command. A gap in its own work is fixed here, by the user in manual; a gap the size of a part becomes a follow-up ticket per the [left for you](../../stations/left-for-you.md) station, cited in the PR. The last deployment, the one no other deployment of the epic waits on, also checks every FR and NFR in the spec, and shows by a run that the problem the plan opened with no longer happens.
2. **Open the PR** per [open a PR](../open-a-pr.md), which keeps its commit per phase, leaves the vault to wrap-up, and gets the verdict through the merge recipe. Its What and why says what users can now do; its Proof gives the deployment's proof as what to try. The PR always waits for the user, who reviews it staged per [the user's review](../merge.md#the-users-review).

## After the merge

Whichever session confirms this deployment merged (the user's review session once the merge recipe lands it, or the one where the user says they merged a manual one) runs `kitchen.zsh order close <KEY>`, then carries on:

- **Deployments still wait**: say that the next one starts with `take <ITS KEY>`, and end.
- **This was the last**: the catering order's wrap-up starts now, in this session. `kitchen.zsh order get <the order's catering>` prints the catering order; claim it with `kitchen.zsh order claim <its key>`, `ExitWorktree`, then `EnterWorktree` with path `.claude/worktrees/<its key>`, and follow [wrap-up](wrap-up.md).
