# Cook: work one order to a merged PR

You are the working session for one order: take it through its recipe, the quality gate, and a verdict to a merged PR, or to the user's review when the order asks for it. The order's `mode` says who writes the code: `manual`, the user writes it; `guided`, you write it with the user here; `auto`, the scheduler runs it headless.

## Starting

Work enters only through the user.

- `take <KEY>` on a ticket with no order, or an order in `new`: run [intake](../serve/serve.md) with the user (`kitchen.zsh order new <KEY>` first when there is no order; it refuses outside a registered project, so offer `/kitchen open` and stop). Intake ends with the order recorded and says where it waits, and so does your turn: an `auto` order goes to the scheduler, and a `manual` or `guided` one waits for `next` or for `take` again. When the user asks at intake to start it now ("work it through in this session"), a `manual` or `guided` order carries on in this session from [Before starting](#before-starting) instead.
- `take <KEY>` on an order that is `ready` or further along: carry on from [Before starting](#before-starting).
- `next manual` or `next guided`: `kitchen.zsh order next <mode>` prints the key of this project's oldest ready order of that mode, by when it became ready. It fails when none waits: say so, and offer `take <KEY>`. Otherwise carry on from [Before starting](#before-starting) with that key.
- `cook new <task in words>` ("new take: add a --dry-run flag") is work with no ticket yet, a question included. Before any other work, file one through the `ticket-provider` skill, its summary and description in the user's words, then run intake on its key: a ticket you just filed is as unchecked as any other.

## The goal line

With the user here, a guided order cooks under a goal, which only they can set. A manual order has none: the user writes it. Hand it over only once the work left runs to the order's rest without them: they agreed on the approach at intake, and no step before the order rests waits on a call of theirs. Until then, work in the session without a goal. When the agreed approach brings a result back for their call (a pick per item, a choice between designs), work to that point, put the call to them, and hand the goal line once they have made it. End the message that carries it with the goal line, and end your turn. Write it from the order's intent and done-when, in plain words, on this pattern:

`/goal <KEY>: <what> is changed to <the new behavior> instead of <the old>, verified by <each done-when check, in a few words>. Done when that is verified and the order rests (merged, or waiting on the user), or when the last messages stop to discuss an immediate problem in the kitchen skill.`

A `catering` order is the standing case: its plan, spec, and implementation plan are written with the user one point at a time, which a goal would push past, and so is each deployment's skeleton. Once a guided deployment's skeleton is approved, the session hands its goal line ([deployment](recipes/catering/deployment.md#the-skeleton) step 5); an auto one runs under the scheduler's own goal.

## Before starting

1. **Claim the order**: `kitchen.zsh order claim <KEY>`, then `kitchen.zsh order get <KEY>`. The user is here only when the `phase` is `cook` and the `mode` is not `auto`, or the order is a catering deployment at its `skeleton` stage ([who is in the session](../../SKILL.md#who-is-in-the-session)).
   - A refused claim says why: another session holds the order, or it was dropped. Tell the user if they are here, and stop.
   - Claiming an `auto` order from the user's session sets it to `guided` for good, except at a deployment's `skeleton` stage.
2. **Claiming set the status to `cooking` and the `phase` to `cook`; `claimed_from` keeps the status before.** Hand them the [goal line](#the-goal-line) right after the claim when its rule allows. A manual order goes the [manual way](#a-manual-order), except a `catering` order, which has no mode, and a catering deployment, which gets there from its skeleton.
3. **Read the order**: intent, done-when, mode, review flag, station, recipe, any `steps`, and the `answer` the user gave at intake, which binds you. Re-read the ticket with the `ticket-provider` skill; a change since intake that moves the intent is a call for the user when they are here, and in `auto` you build the intent as decided and say in the PR what changed on the ticket. When the order has a `retry_cause`, the last session stopped for that reason: `context` means it ran out of room, so keep your own context small this time by handing each remaining step to a fresh agent and keeping only its report; `stuck` or `tool` means it ran on another model and you are the replacement.
4. **A `catering` order** follows [its recipe](recipes/catering.md) from here, and an order with a `catering` field, one of its deployments, follows [deployment](recipes/catering/deployment.md). The rest of this file is for every other recipe.
5. **Enter the order's worktree.** The base branch is what `kitchen.zsh order base <KEY>` prints. If `.claude/worktrees/<KEY>` exists, `EnterWorktree` with that `path`: this is a pickup. Otherwise `EnterWorktree` with `name: <KEY>`; it branches from the default branch, so then `git fetch origin <base>` and `git reset --hard origin/<base>`. Inside the worktree git reaches nothing outside it; when a command is refused for that reason, write it to a scratchpad script and run that by absolute path.
6. **On a pickup, follow the [session pickup](recipes/session-pickup.md) recipe before doing anything.** Its trail is `git --no-pager log --oneline origin/<base>..HEAD`, the order (its `step` names the last step finished), the PR if one exists, and the last session's transcript (`kitchen.zsh order transcript <KEY>` prints the path). When this skill's text caused the stop, address it per [SKILL.md](../../SKILL.md#defects-and-lessons). Never redo committed work. When `git status --porcelain` prints anything, a session stopped mid-step: commit it as `wip: <step>` and review it as part of that step.
7. **If a PR exists** (the order's `pr`, or one the provider lists for this branch, which a session can open and die before recording), record it with `kitchen.zsh order set <KEY> pr=<url>` and read its state through the `git-provider` skill:
   - **Open**: follow the [follow a PR](recipes/follow-a-pr.md) recipe.
   - **Merged**: `kitchen.zsh order close <KEY>`, and end.
   - **Closed without merging**: someone decided against it. With the user here, ask whether to work it again. Headless, closing it was the decision: `kitchen.zsh order set <KEY> status=86 "reason=PR closed without merging: <url>"` and end. To work it again, `kitchen.zsh order set <KEY> pr=` and carry on.
8. **Open the task list** with the recipe's steps verbatim, per [SKILL.md](../../SKILL.md#recipes), or the order's `steps` when its recipe is `bespoke`. When the task tools do not load, note each step's start and finish in prose.
9. **Claim the ticket** through the `ticket-provider` skill (`ticket.zsh claim <KEY>`, which assigns it to the user and moves it with the `start` moment), unless `ticket.zsh holder <KEY>` prints `me` and the ticket is already at or past that moment.

## Working

10. **Follow the recipe.** After each step you finish, run `kitchen.zsh order set <KEY> "step=<n> <step name>"`; the scheduler reads it as progress, and the next session as where you stopped. While you work:
    - Keep the order's `station` current (`kitchen.zsh order set <KEY> station=@<file>`, a JSON array) as you learn which files it touches, since the scheduler keeps other orders off them.
    - When the approach departs from the ticket, comment what changed and why on the ticket.
    - Commit often: a session can die at any moment, and the next one resumes from the branch. The [open a PR](recipes/open-a-pr.md) recipe folds the branch into one commit.
    - A change to something other code reads (an endpoint, signature, schema, shared validator, wire format, database column, config key, or flag) is done only when every consumer is listed, including those grep misses in other languages, services, and stored data, and a run confirms each one survives. The [blast radius](stations/blast-radius.md) station is how.
11. **A recipe that ships a change ends in the [open a PR](recipes/open-a-pr.md) recipe**, which holds the gate, opens the PR, and hands on to [merge](recipes/merge.md). A recipe whose deliverable is an answer (investigation, the forensics recipes, prototype) ends the session itself. An investigation ends in its answer and the tickets it files.

## A manual order

The user writes the code in VS Code, starting from tests written first, which are theirs to change ([contract](stations/contract.md#a-manual-order)). You look things up for them. The recipe's steps that write code are skipped. A catering deployment gets its tests and shape from its skeleton instead, the user writes the bodies, and you check each phase against the plan per [deployment](recipes/catering/deployment.md#manual-phases).

1. Do steps 1 to 3, 5, 6, and 9 above: claim, read the order, enter its worktree, and claim the ticket.
2. Run the [contract](stations/contract.md) station, unless a catering skeleton already wrote the tests.
3. Run `kitchen.zsh handoff <KEY>`. It opens the worktree in a new VS Code window with `code -n`. This session stays where it is; the user moves the conversation into that window themselves if they want it there.
4. Tell the user which tests were written, the command that runs them, that they may edit, replace, or delete any of them, and that they say "done" when the code is in. Then load the `manual-mode` skill and follow it.
5. When the user says "done", commit their work on the order's branch, then run the [open a PR](recipes/open-a-pr.md) recipe, so the gate sees it. The quality gate reports every finding, worst first, with its evidence, and fixes nothing. The user fixes and says "done" again, and the gate reruns what their fixes could change. They may instead accept a finding: it is listed in the PR description under Approach with their reason. When the gate's first run reports nothing, the PR opens without a second "done". Once it is clear, the PR opens and a verify session gives its verdict. A `FAIL` comes back to the user as findings, never as a fix. The PR always waits for the user, and the kitchen never merges it: they do.

## When the scheduler wakes you

The scheduler starts a cook session on a ready `auto` order: follow this file from [Before starting](#before-starting), and never wait for the user. It starts a follow-up session on an open PR when it changed (a review, a comment, a push, a check) or got its verdict. Claim the order first (`order pr` and `order verify` handed it to the scheduler), then follow the [follow a PR](recipes/follow-a-pr.md) recipe. A refused claim means another session holds it: say so and stop.
