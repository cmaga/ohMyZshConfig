# Cook: work one order to a merged PR

You are the working session for one order: take it through its recipe, the quality gate, and a verdict to a merged PR, or to the user's review when the order asks for it.

## A new take

`/kitchen cook new <task in words>` ("new take: add a --dry-run flag") is work with no ticket yet, a question included. Before any other work, file one through the `jira` skill, its summary and description in the user's words, then work its key from [Before starting](#before-starting), intake first: a ticket you just filed is as unchecked as any other.

## Before starting

1. **Claim the order**: `kitchen.zsh order claim <KEY>`, then `kitchen.zsh order get <KEY>`. Its `phase` now says whether the user is here.
   - No order yet, because the user took a ticket the scheduler has not seen: `kitchen.zsh order new <KEY>`, then claim. `order new` refuses outside a registered project; offer `/kitchen open` and stop.
   - A refused claim says why: another session holds the order, intake is running, or it was dropped. Tell the user if they are here, and stop.
2. **Claiming set the status to `cooking`; `claimed_from` keeps the one before.** With the user here (`phase` is `session`), two of them need the user first:
   - `new`: intake has not run. Run [intake](../serve/serve.md) with them, then carry on to the recipe's end, even when intake already found the answer.
   - `at-the-pass`: ask them the order's `question`, unless all it says is to run this session; write their answer to a file, and run `kitchen.zsh order set <KEY> answer=@<file>`. When they say to drop it, run `kitchen.zsh order set <KEY> status=86 reason=@<file>`, comment why on the ticket, and end.
3. **Read the order**: intent, done-when, flags, station, recipe, any `steps`, and any `answer` the user gave at the pass, which binds you. Re-read the ticket with the `jira` skill; a change since intake that moves the intent is a call only the user can make. When the order has a `retry_cause`, the last session stopped for that reason: `context` means it ran out of room, so keep your own context small this time by handing each remaining step to a fresh agent and keeping only its report; `stuck` or `tool` means it ran on another model and you are the replacement. An order with a `spec` and a `base` is a catering milestone: read it per [catering](recipes/catering.md#the-milestone-orders) too.
4. **A `catering` order** follows [its recipe](recipes/catering.md) from here. The rest of this file is for every other recipe.
5. **Enter the order's worktree.** The base branch is what `kitchen.zsh order base <KEY>` prints: a catering milestone's spec branch, else the project's. If `.claude/worktrees/<KEY>` exists, `EnterWorktree` with that `path`: this is a pickup. Otherwise `EnterWorktree` with `name: <KEY>`; it branches from the default branch, so then `git fetch origin <base>` and `git reset --hard origin/<base>`. Inside the worktree git reaches nothing outside it; when a command is refused for that reason, write it to a scratchpad script and run that by absolute path.
6. **On a pickup, follow the [session pickup](recipes/session-pickup.md) recipe before doing anything.** Its trail is `git --no-pager log --oneline origin/<base>..HEAD`, the order (its `step` names the last step finished), the PR if one exists, and the last session's transcript (`kitchen.zsh order transcript <KEY>` prints the path). When this skill's text caused the stop, address it per [SKILL.md](../../SKILL.md#defects-and-lessons). Never redo committed work. When `git status --porcelain` prints anything, a session stopped mid-step: commit it as `wip: <step>` and review it as part of that step.
7. **If a PR exists** (the order's `pr`, or one the provider lists for this branch, which a session can open and die before recording), record it with `kitchen.zsh order set <KEY> pr=<url>` and read its state through the `git-provider` skill:
   - **Open**: follow the [follow a PR](recipes/follow-a-pr.md) recipe.
   - **Merged**: `kitchen.zsh order close <KEY>`, and end.
   - **Closed without merging**: someone decided against it. With the user here, ask whether to work it again, unless their answer at step 2 already said. Headless, closing it was the decision: `kitchen.zsh order set <KEY> status=86 "reason=PR closed without merging: <url>"` and end. To work it again, `kitchen.zsh order set <KEY> pr=` and carry on.
8. **Open the task list** with the recipe's steps verbatim, per [SKILL.md](../../SKILL.md#recipes), or the order's `steps` when its recipe is `bespoke`. When the task tools do not load, note each step's start and finish in prose.
9. **Move the ticket** with `transitions.start` and assign it to the user through the `jira` skill, unless it is already at or past that status and assigned to the user.

## Working

With the user here, hand them this line to paste, with the order's key, and end your turn:

`/goal Carry order <KEY> through /kitchen cook to its end. The goal is met when kitchen.zsh order get <KEY> prints a status other than cooking, or when the last message stops to discuss a problem in the kitchen skill with the user.`

10. **Follow the recipe.** After each step you finish, run `kitchen.zsh order set <KEY> "step=<n> <step name>"`; the scheduler reads it as progress, and the next session as where you stopped. While you work:
    - Keep the order's `station` current (`kitchen.zsh order set <KEY> station=@<file>`, a JSON array) as you learn which files it touches, since the scheduler keeps other orders off them.
    - When the approach departs from the ticket, comment what changed and why on the ticket.
    - Commit often: a session can die at any moment, and the next one resumes from the branch. The [open a PR](recipes/open-a-pr.md) recipe folds the branch into one commit.
    - A change to something other code reads (an endpoint, signature, schema, shared validator, wire format, database column, config key, or flag) is done only when every consumer is listed, including those grep misses in other languages, services, and stored data, and a run confirms each one survives. The [blast radius](stations/blast-radius.md) station is how.
11. **A recipe that ships a change ends in the [open a PR](recipes/open-a-pr.md) recipe**, which holds the gate, opens the PR, and hands on to [merge](recipes/merge.md). A recipe whose deliverable is an answer (investigation, the forensics recipes, prototype) ends the session itself. An investigation leaves its order at the pass, not closed, until the user picks the change it leads to.

## When the scheduler wakes you

The scheduler starts a session on an open PR when it changed (a review, a comment, a push, a check) or got its verdict. Claim the order first (`order pr` and `order verify` handed it to the scheduler), then follow the [follow a PR](recipes/follow-a-pr.md) recipe. A refused claim means another session holds it: say so and stop.
