# Kitchen: a 24/7 engineering line run by a head chef

The design of the engineering line on branch `kitchen`, decided in conversation on 2026-10-28. On this branch the kitchen absorbs `dev-workflow`; `main` keeps dev-workflow, so the branch itself is the comparison. See [What is built](#what-is-built) for the files and the calls made while building. A redesign decided and built on 2026-11-15 changes how work enters the line and who does it: see [Redesign: three modes](#redesign-three-modes). Where an earlier section disagrees with it, the redesign holds.

---

## Goal

You are the head chef. You set the rules and recipes, delegate, and spot-check. Everyone else in the kitchen does the cooking. Orders come in 24/7 and PRs go out 24/7.

Requirements:

1. Never stops; high volume.
2. High quality.
3. Self-tuning.
4. Token efficient.
5. Works with whatever board a project has. No special board setup.

Two beliefs it is built on:

- You cannot review every line AI writes.
- Code is only as good as the level at which it is checked. An agent told to focus on one thing does that thing well and misses what sits next to it.

So you own *what* gets checked, and the kitchen does the checking, on every change.

---

## The brigade

| Role | Who | Does |
|---|---|---|
| Head chef | You | Writes house rules and recipes, signs off and reviews where an order asks for it, tastes samples |
| Server | A session per ticket | Turns a raw ticket into an order, or closes it |
| Expo | A shell script on a timer | Watches the board and the rail, fires orders, restarts what fell over. Spends no tokens |
| Sous chef | The main session of one order | Runs the order's recipe, fires line cooks, holds the quality gate |
| Line cooks | Worker agents | Each cooks one station (a set of files no other cook touches) |
| Tasters | Narrow judgment checkers | Each tastes for one thing only |
| Thermometers | Lint, types, tests, scripts | Deterministic, run on every plate |

## Vocabulary

| Kitchen | Engineering |
|---|---|
| Customer | A raw ticket. Often a placeholder, sometimes stale or wrong |
| Order | A ticket the server has verified and written up. Always 1:1 with a ticket |
| Order book | Local per-project state, outside the repo, uncommitted |
| Rail | Orders ready to cook |
| Mise en place | Worktree, scaffold, failing tests |
| Fire | Dispatch line cooks. `/kitchen fire` is the other kind, a fire in the kitchen: a production incident |
| Taste as you go | Verify each piece before starting the next |
| The pass | Thermometers and tasters check the plate before it goes out |
| Clean as you go | The tidy taster: fix what is messy or unintuitive, within reach |
| Pantry | Existing code, reused before anything new is written |
| 86 | Won't do |
| Cookbook | Global recipes, one per engineering task |
| House | Per-project rules, thermometers, and verify skill, committed to the project |

### In the directions

File and directory names carry the analogy (`kitchen/`, `recipes/`, `stations/`, `cook.md`, `serve.md`, `taste.md`, `roster.md`, `house.md`, `taster-agent`, `kitchen.zsh`), and so do command names, since each is a file name. The instructions agents read use plain words, so no agent picks up the lingo and starts writing about cooking:

| Kitchen | In the directions |
|---|---|
| Head chef, chef | the user |
| Sous chef | the session working the ticket |
| Server, serving | intake |
| Expo | the scheduler |
| Rail | the ready queue |
| Line cook, prep cook | worker, tester |
| Tasters, thermometers | reviewers, checks |
| The pass, tasting sample | the quality gate, review sample |
| House rules | project rules |
| Station | task card for a worker; a job's `files` |
| Fire | dispatch |
| 86 | dropped |
| The line, restaurant | the pipeline, project |
| Catering, mise en place | a plan, spec, and implementation plan, shipped in deployments; prep |

"Order" stays in the prose: an order is the server's verified write-up of a ticket, a different thing from the ticket itself.

Commands and what they read and write keep the kitchen names too: `kitchen.zsh order ...`, `line ...`, `catch ... --chef`, the `station` field, and the statuses (`serving`, `cooking`, `86`). Only the prose around them is plain.

---

## Orders

The server reads a ticket, checks it against the code (still a problem? already fixed? written wrong?), and writes an order: the intent in plain words, the done-when checks, and two flags.

| | No review | Review |
|---|---|---|
| **Decided** | The line starts it and merges it | The line starts it; the PR waits for you |
| **In the review queue** | You make the call, then the line starts and merges it | You make the call, then review the PR |

- **Review** is set when any line of the done-when is something only you can judge, such as look and feel. "The page loads with no error, and errored before the fix" needs no review.
- **The review queue** is where a ticket waits when it needs a call only you can make before it becomes an order: whether to do it, how, what instead, and how it will look. An order is decided work and runs end to end.
- **No bounce.** A call that comes up while cooking is the cook's: decided, logged, and flagged on the PR when you would want to see it. Only a decided premise that proves impossible withdraws the order back to the review queue.
- **Not every customer is served.** The server closes stale tickets and rewrites wrong ones in the tracker itself, with a comment saying why.
- **Shallow rail.** The server takes orders in priority order only until the rail has a few queued, so placeholder tickets at the bottom of the backlog cost nothing.
- **1:1 with tickets.** An order the kitchen creates for itself (a promotion, below) files its ticket first.

## The line

- The expo is a shell script on a launchd timer, on this Mac for now. It runs one tracker query through `ticket.zsh ready`, the project's "ready" section, whatever the board calls it. Polling costs no tokens; Claude starts only for a ticket to serve or an order to cook.
- Each order runs headless through `oc`, from the project directory, so the right account is used: `cd <project> && oc -p "<order>" < /dev/null`. Several orders cook at once, each in its own worktree.
- A crash or a rate limit puts the order back on the rail with a retry count. A rate limit means wait, never quit, and the project's line starts nothing until it lifts.
- The expo holds no state but the order book, so a restart resumes where it stopped.
- The line only cooks while this Mac is awake.

## Safety

- The line never deploys to production. A merge that triggers a project's own auto-deploy is the project's accepted risk; nothing extra is built around it. The one exception is `/kitchen fire`, which ships a mitigation only with you there and on your go.
- The server may change the tracker.

---

## Quality: the food loop

How a project's code stays good. Separate from the kitchen loop below.

**House rules.** Each project carries a committed table. Every rule names what enforces it; a rule with no enforcer is not on the bar.

| Rule | Enforced by |
|---|---|
| No new `any` in TypeScript | `eslint no-explicit-any` (check) |
| Names say what a thing is for, not how it works | `naming` taster (judgment) |
| Tidy what is unintuitive, reach: touched files | `tidy` taster (judgment) |

- A deterministic check wherever one can do the job. Checks live in the project's own lint, hooks, and CI, so humans and CI hit them too.
- Text only for real judgment calls, read by a taster.
- Reach is set per project. A production app tidies only the lines a change touched; a personal repo tidies the neighborhood.

**Tasting.** You review at least one PR per project per day. Your review comments on it are catches.

**Promotion.** Every catch is logged in the order book with a class. A class seen twice is promoted; your catches promote on the first sighting.

The ladder, strongest first:

| Rung | The slip becomes | Rail |
|---|---|---|
| 1. Structure | Impossible: the wrong way no longer exists | Review queue (new structure) |
| 2. Types | Unwritable | Line |
| 3. Lint | A build failure whose error names the fix | Line |
| 4. Test | A failing test | Line |
| 5. House rule | A sentence a taster reads | Review queue |

1. **Catch.** First sighting, logged. Nothing changes.
2. **Promote.** Second sighting: an order to enforce the class at the highest rung that works, saying why each higher rung didn't. Done-when: the enforcement fails on both original slips and passes on main.
3. **Record.** The house rules table gains the row and the catches behind it.
4. **Climb.** A slip that gets past an existing enforcement means it didn't take. The next order lands at least one rung higher, or goes to you.
5. **Retire.** A lower rung made redundant by a higher one is deleted. The only way the table shrinks.

Calls that reach the review queue climb a two-rung ladder of their own: a sentence in intake's notes, then a `## Sorting` rule in the project rules, which intake applies before its own judgment.

## Self-tuning: the kitchen loop

How the kitchen's own process improves. Same shape as today's memory loop.

- A defect in the kitchen itself (a recipe, a station, the scheduler) is fixed right away only when it is broken: a script errors, or a path, command, flag, or link names nothing. The fix is committed on `main` in ohMyZshConfig and deployed, and the cook carries on with its order. Anything else is a skill lesson for your memory review, where you agree the change in plain words and see the rendered text, unless you pick it in a `/kitchen reflect`, which edits it and leaves it uncommitted for you (2026-11-03: this replaced a PR per defect, since a markdown diff did not get a real review).
- A project nuance that caused confusion, delay, or difficulty goes to auto memory. Your memory review decides what each becomes: a project change (hook, rule, skill), a global change, a kitchen change, or nothing. Memory is never committed into a project.
- Catches about a project's code go in that project's order book, never memory: memory loads into every session on this machine and has a read limit.
- A change to the kitchen is proven by its saved eval cases (`dependencies/evals/`, run with the `skill-eval` skill) before it is committed, never in pre-commit. A fix for something broken skips them.

---

## Redesign: three modes

Decided in conversation and built on 2026-11-15. Where an earlier section disagrees, this one holds; [What it replaces](#what-it-replaces) closes the section.

### Why

The kitchen checks work against your standard and cannot supply one. Tasters, house rules, and promotions enforce consistency with what the project already does; intake and review rest on your judgment. In a technology you do not know, the first patterns the agents write become the standard, and the catch loop locks them in. And you learn nothing while the line cooks. The order books showed it, one finding behind each change:

- **Manual mode.** act_to_recover (Flutter) logged 14 catches. 2 were yours, both product issues (a watermarked stock image, text overflowing at large font sizes); none was about the code's design.
- **Intake only with you.** engine dropped or parked 9 of the 55 tickets intake served, at least 7 by your call at intake. Headless, intake would have guessed on each.
- **Review set at intake.** 31 of engine's 33 PRs waited for your review, 20 of them for a path on its `## Always review` list, and 2 of its 1,305 catches were yours. A review that holds everything tells you nothing.

### Work enters only through you

- A ticket enters the line only when you type `take <KEY>`, which runs intake with you. The scheduler stops reading the board, and headless intake goes.
- At intake you decide whether the ticket is worked at all, its approach, its mode, and whether its PR waits for your review. Then an auto order goes to the scheduler, and a manual or guided one waits until you start it with `/kitchen next` or `take <KEY>` again.
- This gives up requirement 1 of the [Goal](#goal), never stopping and high volume: volume is capped by your intake time, in exchange for never cooking an order you would not have approved. Requirement 5 still holds, since `take` works with any tracker the `ticket-provider` skill reaches.

### Three modes

Every order carries a `mode`, set at intake:

| Mode | Who writes the code | Who starts it | Can it ask you |
|---|---|---|---|
| manual | You, tests included. The AI fills in what you would otherwise look up and answers your questions | You | Yes |
| guided | The line, with you in the session | You | Yes |
| auto | The line, headless | The scheduler | Never |

- **Starting.** `/kitchen next manual` or `/kitchen next guided` claims the project's oldest waiting order of that mode, by when you approved it at intake, and works it. It is a row in `SKILL.md`'s command table that points at `cook.md`, and `kitchen.zsh order next <mode>` prints the key. `take <KEY>` starts a specific one.
- Whatever the mode, the verdict comes from a session or agent that did not write the change and never asks, and PR follow-ups always run headless.
- Asking for an auto order's session ("give me the 123 session") makes it guided for good.
- The order's `phase` field says what kind of session holds it. It loses `serve`, since headless intake goes, and `session`, which marked an order worked in a session with you (`SKILL.md`, "Who is in the session"), since `mode` now says that.

### Choosing the mode

**Unlocking modes.** Every project starts manual-only. Per project in `line.json`, `guided_after` merged manual orders (default 5) unlock guided, and `auto_after` merged guided orders (default 5) unlock auto. The counts start at 0 in every project, engine and act_to_recover included, since an order merged before modes existed counts toward nothing; `kitchen.zsh line set <slug> guided_after=<n>` lowers a threshold. This replaces `probation`, which held a project's first 5 PRs for your review.

**The recommendation.** Intake recommends a mode from `commands/serve/mode.md`, beside the approach, in one line: the mode, the reason, and the rule that decided it. You approve or change it. Intake offers only the modes the project has unlocked; among those, the first rule that matches decides:

1. **A `## Sorting` rule.** The project rules' rules that intake applies before its own judgment when it sets a ticket's flags. It is your earlier call.
2. **Manual, for risk**, when a mistake would cost a lot and the checks could not catch it: a data model, an interface between components, failure behavior. A path in the order's `station` (the files intake expects it to touch) that the project rules list under `## Critical` (where a mistake loses money, data, or a safety check) or `## Always review` counts toward it.
3. **Manual, for practice**, when under 15% of this project's orders in the last two weeks were manual.
4. **Guided** when calls only you can make are likely mid-work: open design questions, unclear scope, no precedent in the repo, or an area where an earlier order in this project was parked.
5. **Auto** otherwise: a bug fix with a reproduction, a refactor whose behavior the tests pin, a mechanical change.

No project section is added. Every override you make is logged in the order book (ticket, recommended, chosen, why) and climbs into `## Sorting` by the two-rung ladder in [Quality](#quality-the-food-loop).

### Auto orders never wait on you

An auto order always reaches its PR. Where today's line stops, it carries on:

| When | Today | Auto |
|---|---|---|
| A hard call while cooking | The escalation agent (the `escalation` role in `SKILL.md`'s Subagents) decides | Unchanged; the call is also listed in the PR |
| A product call made alone | The escalation agent decides, and the PR waits for your review | Unchanged |
| A fix that cannot ride the branch | A Left for you item, which holds the PR for your review | It files a follow-up ticket and cites it in the PR. That is safe now, since a ticket enters the line only through `take` |
| The approach you approved proves impossible | `order withdraw` sends it back to the review queue | The escalation agent replans, and the PR waits for your review, since it overturns your decision |
| An irreversible step outside the branch | A bounce, like a production deploy | Never taken; the PR says so |
| An investigation finishes | Its order waits in the review queue until you pick the change | It ends in its answer and the tickets it files |

### Manual orders

- **The writing help is a new standalone skill**, `manual-mode`, a technique like `frontend-design` that knows nothing of orders, gates, or PRs. To fill in something you would otherwise look up, you select the name and ask in the Claude panel. It inserts only that (the import, the type, the call), never the logic, and shows the shape of the data that comes back in one line.
- **The editor.** You write in VS Code with the Claude Code extension, which shares the open file and your selection with Claude. Edits land in its edit-automatically mode, and its `autosave` saves your buffers before Claude's tools run.
- **Its own window.** Worktrees sit under a git-ignored `.claude/worktrees/`, and the panel withholds selections from git-ignored files, so the order's worktree opens as its own VS Code window. `/kitchen next manual`:
  1. claims the order and creates its worktree;
  2. opens the worktree with `code -n`;
  3. runs `kitchen.zsh handoff <KEY>`, which ends the terminal session (its `claude` process, which Claude Code exposes as `CLAUDE_PID`), waits for it to exit, and opens the same conversation in the new window with `vscode://anthropic.claude-code/open?session=$CLAUDE_CODE_SESSION_ID`.
- **Tests.** You write them too, so a manual order skips the contract station. The verify session's own inputs, the mutation sweep, and the test-honesty and gaming tasters still check your work. The order records your test command for the sweep, and taste and verify accept `contract-check.sh`'s exit 2 (no contract commit) on a manual order.
- **Ending.** You say "done" in the panel. The gate reports every finding, worst first, with its evidence, and fixes nothing. You fix them and say "done" again; the gate reruns what your fixes could change. The kitchen opens the PR, and a verify session gives its verdict; a FAIL comes back to you as findings. The PR always waits for you, and the kitchen never merges it: you do, as with catering's final PR.

### Review

- Whether a PR waits for your review is set at intake, forced to yes by a surprise, and always yes on a manual order. A review always means you reading the PR in the browser.
- A surprise is a deleted test, a silenced or changed check, a `## Review when` question (one the verify session answers for every change) judged yes, or an `## Always review` path outside the order's `station`. Paths inside the station were weighed at intake, which is what ends the 20 engine PRs held by that list alone.
- A PR is finished code. No question rides on it and no comment addresses you. Calls made alone go in its description under Approach. This reverses [open a PR](../src/storage/claude/skills/kitchen/commands/cook/recipes/open-a-pr.md), which keeps them out of the PR, in the order's `decisions`; the "Decided alone" list that [Calls made while building](#calls-made-while-building) describes was never built.
- To change a PR, you ask for its session and work it as guided; `kitchen.zsh review <number> --line` already prints the command.

### Status

Everything is per project: status, `/kitchen next`, the practice share, and the unlock counts. No view spans projects.

| | Today | Redesign |
|---|---|---|
| Scope | Every project, with one last-look marker for all | The current project, with its own marker; outside a project it says so and stops |
| Waiting on you | QUEUED, PROMOTE, BLOCKED, REVIEW | PROMOTE, BLOCKED, REVIEW |
| Ready for you to start | Nothing | Waiting manual orders, then guided |
| Since you last looked | merged, dropped, decided, promoted, notices | The same plus filed tickets, with the calls made alone shown under each merge you did not review |

### A work session

Decision windows of 20 to 30 minutes alternate with focus blocks of 90 to 120. In a window you read status; review the held PRs, starting with those other orders wait on; take new tickets, and the ones you set to auto start cooking at once; then run `/kitchen next manual` for the coming block. In a block you work the manual order, and nothing interrupts it.

### Before the scheduler is turned back on

1. **A committed stub harness**, `dependencies/tests/scheduler.zsh`, since the one behind the 47 cases in [Verified](#verified) was never saved. Its 83 cases cover the paths that survived this redesign and each new one.
2. **A dry run.** `kitchen.zsh tick --dry-run` on the timer for a day against a real project's orders and PRs, its log read for any wrong call.
3. **A supervised run** on a personal repo, with `guided_after` and `auto_after` at 0 there: one auto order, `max_cooking` at 1, and review set at intake. `kitchen.zsh line pause <slug>` stops new work while running sessions keep their time limits and stall checks; dropping an order stops its session on the next pass.
4. **The first real project**, once auto unlocks there.

### Closed and declined

- **Notifications**: none. Status at each decision window covers it.
- **A weekly tour** of the merges you did not review: declined as not worth its overhead. Add it only if familiarity becomes a problem.
- **A separate tutor mode**: a tutor is you asking questions in manual mode.
- **Dictation** in manual mode: typing for now; it can be added later.

### What it replaces

| Today | Under the redesign |
|---|---|
| The scheduler reads each project's ready query ([The line](#the-line)) | Goes. Work enters through `take` |
| Headless intake on `sonnet`, its time limit, and the shallow rail (`rail_depth`) | Go |
| The review queue, where intake parks a call for you ([Orders](#orders)) | Goes. Every call it held is made at intake with you |
| The two flags in [Orders](#orders) | `mode` and the review decision at intake |
| Promotions open an order in `new` for intake; the ladder's Rail column | A promotion files its ticket, which enters the line when you take it |
| `probation` | Unlocking modes |
| An `## Always review` path inside the order's files holds the PR | Weighed at intake instead |
| The daily sample: one PR per project per day waits for you ([Tasting](#quality-the-food-loop)) | Goes. Your catches come from the changes you ask for in an order's session |
| Left for you items that hold a PR | Follow-up tickets in auto; questions asked live in guided |
| `order withdraw` | The escalation agent replans and the PR waits for you |
| Calls made alone kept out of the PR | Listed in its description under Approach |
| You ask for a change in a PR comment | You ask in the order's session, which becomes guided; follow-ups still handle other reviewers' comments |
| `phase` values `serve` and `session` | `mode` |
| One status across every project | Status per project |

### Unverified

- The session link reaching the new VS Code window rather than another open one.
- The conversation's last turn surviving the terminal session's end in the handoff.

---

## Redesign: catering

Decided in conversation and built on 2026-11-18. Where an earlier section disagrees about catering, this one holds; [What it replaces in catering](#what-it-replaces-in-catering) closes the section.

### Why

- **It had become its own thing.** Catering ran its own research loop and adversarial review (`spec.md` steps 3 and 9) beside the how, why, prototype, architect, and interrogate stations that do the same work for every other order.
- **No plan for people.** The first document was the spec, an architecture page for agents. Nothing short existed for you or a team to review and refine.
- **A manual-only project could not take it.** `mode.md` allowed a catering spec only `guided` or `auto`, and every project starts manual-only. Past that, the close and every milestone ran headless whatever the mode.
- **Milestones assumed one deploy.** Capability slices merged into `spec/<EPIC>` and shipped at the end in one PR, so the milestones said nothing about the road to production.
- **A spec says what the system does, not what the code looks like.** An agent handed one still makes every structural call: module boundaries, types, which pattern to copy. In a new codebase the first code becomes the pattern everything after it copies, and a PR that size is too large for anyone to read.

### The stages

| Stage | You | Built from |
|---|---|---|
| Context, goals, requirements | Agree them | Intake's first two stages, extended to goals and requirements |
| Investigation | Not needed; it runs in the background | The how and why stations, the look-it-up principle, the prototype recipe for anything a run settles |
| Direction | The recommendation, then your lean, back and forth until you agree | Intake's recommendation stage, the architect station for competing designs, interrogate on the chosen one |
| Plan | Refine every line | The plan template and the technical-writing station |
| Spec | Glance | Written from the plan, for agents |
| Implementation plan | Answer each call as the walk reaches it: the session follows the spec's flows hop by hop in the order data moves, brings up each call you should make where the flow meets it, and settles the obvious ones without showing them | The gather and decisions of today's plan step, and the architect station |

None of these stages has a mode. Each runs with you, so catering works in any project.

### The documents

All three are markdown, edited in place, with mermaid diagrams. They live in the catering order's worktree under `.claude-artifacts/`, which git ignores, so no PR carries them, and deployment sessions read them by absolute path. The catering order stays open until wrap-up, since pruning a closed order's worktree would delete them: ignored files do not count as uncommitted changes (`land_worktree` in `kitchen.zsh`). The Artifact pages go: `spec-template.html`, `plan-view.html`, and `plan-view.py`.

- **The plan**, after Google's design docs (Malte Ubl, "Design Docs at Google", 2020): 1 to 3 pages, no schemas or code. Context and scope; Goals and non-goals; Direction (your lean, the recommendation, what was chosen and why); How it works (an overview, the trade-offs, one context diagram); Alternatives considered; Cross-cutting concerns; Rollout (how many deploys, what ships in each, why each is separate); Open questions, empty before the spec starts.
- **The spec**, functional and for agents. A header naming what it builds and linking the plan; Terms; Functional requirements `FR-N`, each a checkable sentence traced to a goal; Non-functional requirements `NFR-N`, each with a measurable bar; Parts, `C-N` for what we run and `X-N` for outside services, each with Owns, Talks to, Behavior (`C-2.3`, citing its FR), Data, and Tests (citing behaviors and NFRs); Flows, as mermaid sequence diagrams; Records; Starting values. Every FR reaches a behavior and every NFR a test.
- **The implementation plan.** Decisions `DEC-N`: the call, why, and what it beat; one that fixes a shared interface states the contract itself (signature, data shape, errors). Coverage: each FR, NFR, behavior, and test to the task that delivers it. The checks today's code performs and the behavior the build deletes, each with a fate, as today. Then the deployments.

### Deployments

A deployment replaces the milestone. A new one starts only when the next change cannot ship until the previous one is live in production:

1. **Old and new must coexist across a deploy.** A schema or API change whose readers and writers deploy separately, or whose clients you do not deploy, runs expand, migrate, contract (Danilo Sato, "ParallelChange", 2014).
2. **Data must exist in production first.** A migration or backfill runs on real data before the code that relies on it.
3. **Something outside the repo happens in between**: infrastructure, config, a third-party setup, or a flag turned on once the deploy is checked.

Everything else rides in the earliest deployment it can, so with no boundary the work is one deployment. Each names the rule that forced it and its proof, one check that fails before it and passes after. Each becomes one ticket under the epic, one order, and one PR to the base branch, with one commit per phase. The rules that split a milestone of more than about 30 items and kept it cheap to throw away go; deploys alone size it.

### Phases and tasks

```
## Deployment 1: <what goes live>
   Forced by / Proof / Touches
   Phase 1: Skeleton   shared types, signatures and stubs with their behavior stated, the locked tests
   Phase 2: <name>     tasks, each with depends_on, files, Consumes/Produces (DEC-N), moves/adapts/new
```

- **Phase 1 is the skeleton**: the modules, the types, the signatures with their behavior described, the pattern to follow, and the locked tests. The session researches the standard patterns for the stack and kind of feature, drafts it, and refines it with you until you approve it. It has no mode. You learn the stack's standards here, not by writing every line.
- **Later phases are layers of the task graph.** Each task declares `depends_on` and `files`, and the phases follow from them. `check-plan.mjs` fails on a file shared within a phase, or a producer and its consumer in one phase.
- **One task per phase by default.** A phase fans out only with a one-line reason that its tasks share no file, no interface a DEC fixes that both write, and no producer and consumer pair, and it holds at most about three. Splitting coupled code cut agent success by 30 to 74% in CooperBench and ParallACT, and a full interface spec raised two-agent integration from 25% to 58% in the Specification Gap (2026 preprints).
- **Each task runs in a fresh worker.** Before its work merges into the deployment's branch, its diff stays inside its declared files and leaves the locked tests untouched. Locked tests from a separate, stronger author is the form of test-first the evidence favors (ExecCritic, 2026 preprint: 61.2% to 65.3% resolved on SWE-bench Verified, and 57.3% with a weak author).
- **The phase gate** is the full suite on the merged result, then a verifier who wrote none of the phase reading the diff against the DECs its tasks cite. Its findings go to the session, which fixes them before the next phase; none reach the PR.
- **Long-lived lanes and start-when-ready scheduling inside a deployment are rejected.** A phase boundary is the only point where parallel work inside one PR is tested merged, and lanes pile up context and drift.

### Modes

The planning stages and the skeleton run with you. The bodies, phase 2 on, run in the project's highest unlocked mode: auto, else guided, else manual. The mode decides who writes them; the process is the same.

- **In manual** you write the bodies, and the session checks each phase against the implementation plan when you say "check": as planned, different and better (and why), or different and worse (why, and what the plan had). The `manual-mode` skill stays a lookup helper that knows nothing of plans; the check lives in the kitchen's manual-order section.
- **A better route rewrites the plan at once**, in any mode: the later steps it changes, with any design question it raises discussed then.
- **Every manual order gets its tests from the contract station** before the VS Code handoff, as a deployment gets them from its skeleton. This reverses [Manual orders](#manual-orders) above, where you wrote the tests too.
- **Each deployment is its own ticket, started with `take <KEY>`.** An auto one goes to the scheduler once its skeleton is approved.

### Review

- **Before review, the deployment checks the whole.** Every coverage row it owes is delivered by its code and a passing test. A gap in its own work is fixed there; one the size of a part becomes a ticket. The last deployment also checks every FR and NFR in the spec, and that the problem the plan opened with no longer happens.
- **Every deployment waits for you.** You are the last check: you decide whether it needs revisions, and whether it merges and deploys.
- **A staged review, for catering only.** The kitchen checks the PR's head out into a separate review worktree, soft-resets it to the merge base so every change shows staged in your editor, and opens it as its own VS Code window. The PR branch keeps its commits. You ask the order's session for revisions, made by whoever the mode says, and each gets a fresh verdict and a rebuilt review worktree. Approving merges it, which is the deploy.

### Wrap-up

The scribe does nothing until the last deployment merges, so it never documents code still changing: deployment orders skip the vault step of [open a PR](../src/storage/claude/skills/kitchen/commands/cook/recipes/open-a-pr.md) step 3. Wrap-up starts in the session that confirms the last deployment merged, with you there and no command to type, and runs without a goal. Then:

1. **The planning documents retire into documentation.** The scribe updates the vault from the final spec, and the project's own doc requirements are met in their own PR, or wherever the project keeps its docs. The three documents are attached to the epic for the record.
2. **Cleanup.** The epic and the catering order close, and pruning removes the worktree with the untracked documents.

A new required `## Docs` section of the project rules says where the project's docs go and what a change must update. `kitchen.zsh house` prints `not set up` for a project that lacks it, so every existing project takes no new work until `/kitchen open` adds it.

### What it replaces in catering

| Today | Under the redesign |
|---|---|
| The spec, written with you, as the first document | The plan with you, then the spec for agents, then the implementation plan |
| Catering's own research loop and adversarial review | The how, why, prototype, architect, and interrogate stations |
| Artifact pages: the spec and the plan view | Markdown with mermaid, untracked in the catering worktree |
| The spec's own PR | None |
| Milestones: capability slices, M-1 the thinnest end-to-end path | Deployments, one per forced deploy |
| Milestones in parallel wherever no `After` path joins them | Deployments one after another, each once the one before is live |
| `spec/<EPIC>` and the close's one PR to the base | One PR per deployment to the base branch |
| One mode for every milestone, and none possible for the spec in a manual-only project | No mode for planning and the skeleton; bodies in the highest unlocked mode |
| Review picked per milestone at plan time | Every deployment waits for you, in a staged review worktree |
| The close: census, deviations, vault notes per part | The check before each deployment's review, and wrap-up after the last |

### Unverified

- No coding study compares phase boundaries with a dependency graph inside one PR. The choice rests on where the merged result gets tested, and on Kiro and GSD converging on waves.
- Citing `DEC-N` per task is untested; no tool reviewed does it.
- Most of the parallel-coding evidence is 2026 preprints read as abstracts or summaries.
- A manual order now gets its signatures from the contract author's scaffold, and you write the logic inside them. Whether that still gives you enough practice is untested until you have worked a few manual orders.

---

## What is built

The floor plan in the repo's `CLAUDE.md` places every skill, agent, rule, and hook in one area. The kitchen's own pieces:

| Path under `src/storage/claude/` | Role |
|---|---|
| `skills/kitchen/SKILL.md` | The router, after pstack's poteto-mode: commands, the order book, who is in the session, non-negotiables (trigger to station), the principles index, autonomy, the role table for subagents, how to write the reply and comments, the recipe list, and defects and lessons |
| `skills/kitchen/` layout | One directory per command under `commands/`; `SKILL.md` is the only loose markdown file; `dependencies/` holds the scripts and the scheduler loop |
| `commands/status/status.md` | `/kitchen status`: the chef's catch-up and what waits on them. The rail is only the ready queue |
| `commands/serve/serve.md` | The server. Every order starts from a ticket |
| `commands/serve/mode.md` | The mode recommendation intake gives with the approach |
| `commands/open/open.md`, `open/templates/house.md` | Opening a restaurant, which writes its house rules and verify skill |
| `commands/cook/cook.md` | The sous chef: claim, read, worktree, pickup, the recipe, and the scheduler's wakes; `cook new <task>` files a ticket for work that has none |
| `commands/cook/recipes/` | pstack's playbooks as recipes: feature, bug-fix, refactor, perf, hillclimb, investigation, runtime-forensics, trace-forensics, prototype, change-a-skill, eval, multi-phase-plan, autonomous-run, session-pickup, pause-safely, and the PR lifecycle open-a-pr, follow-a-pr (babysit), merge (shipping); plus enforce and catering (`catering/plan.md`, `spec.md`, `implementation.md`, `deployment.md`, and `wrap-up.md`; see [Redesign: catering](#redesign-catering)) |
| `commands/cook/stations/` | pstack's skills as stations: how, why, blast-radius, architect, contract (from pstack's tdd), arena, swarm, figure-it-out, interrogate, no-comments, benchmark-checklist, unslop, technical-writing, show-me-your-work, ketchup, correct, create- and maintain-verification-skill; and `left-for-you.md` |
| `dependencies/principles/` | pstack's 24 principles plus look-it-up, read when applied |
| `dependencies/evals/` | Saved eval cases in `claude plugin eval` layout |
| `commands/cook/templates/`, `commands/cook/scripts/` | The catering plan, spec, and implementation plan templates, the exit report; `check-plan.mjs`, which also checks an implementation plan |
| `dependencies/scripts/kitchen.zsh` | Order book, status, expo, prune; shared by every command |
| `automation.toml`, `dependencies/scripts/run.zsh` | The expo as a launchd KeepAlive agent. **Off** (`enabled = false`) |
| `commands/taste/calibrate.md` | Taste bud calibration, `/kitchen taste calibrate`: brings the verify skill back in line with the app |
| `commands/taste/taste.md`, `taste/done-when.md` | The pass, also `/kitchen taste` on any branch: done-when, thermometers, tasters, no-comments, and the bug review (the interrogate station) |
| `commands/taste/verify.md` | The verdict, `/kitchen taste verify <KEY>`: a session that did not write the change runs it and records PASS, PASS+NOTES, or FAIL |
| `commands/roster/roster.md`, `commands/roster/` | Model and effort per type of work, was `optimize-usage`; the vault agents left it, pinned to opus |
| `commands/reflect/reflect.md`, `commands/reflect/` | `/kitchen reflect`: three reviewers mine the session for lessons; the kitchen rows you pick are edited and left uncommitted for your review, and the rest route per Defects and lessons. pstack's manual `/reflect`; a station until 2026-11-03 |
| `commands/fire/fire.md` | `/kitchen fire`: a production incident worked with you, root cause to mitigation, each step on your go; the long-term fix and any remedy leave as tickets for the line. `open` asks for the project's `## Production` facts |
| `agents/taster-agent.md` | One narrow judgment checker |
| `dependencies/tests/scheduler.zsh` | The stub harness: the scheduler script against fake `oc`, `gh`, `code`, `open`, and tracker, in a throwaway sandbox |
| `skills/manual-mode/SKILL.md` | The writing help a manual order's VS Code session loads; standalone, outside the kitchen |
| `agents/worker-agent.md`, `agents/comment-sicko-agent.md` | The line cook, pstack's poteto-agent: reads `SKILL.md` before work; and the comment hater the no-comments station spawns |

dev-workflow's `cleanup` is gone. The scheduler closes an order when its PR merges (or the session that merged it runs `order close`) and removes its worktrees then; `kitchen.zsh prune`, daily from the scheduler, clears what is left. Prune touches only the worktrees of closed orders no session holds: a merged order's whatever its branch's ancestry, squash merges included; a dropped order's only when its branch changes nothing the base lacks; never a worktree the pipeline did not create. It runs the worktree's teardown and syncs the vault first, and a failed teardown or a `vault:` line becomes a `notice` in the catch-up.

### Calls made while building

- **pstack is forked, not a dependency** (2026-10-29). Lauren Tan's pstack skills became the kitchen's recipes, stations, and principles, adapted to Claude Code and kitchen names, in one skill. Routing is per task (match the work to a recipe), replacing size tiers. Left out: formal verification, statechart, make-bot-ui, ketchup-video, typescript-best-practices, teach, bro, in-your-own-words, sharpen, recall, automate-me, poteto-help, setup-pstack (the roster covers models), and the benny pack apart from intake's triage shape. Orchestrate and autopilot fold into the scheduler.
- **Research before choosing** (2026-10-31). pstack has no research principle, and the port dropped dev-workflow's solution research. The architect station's Phase A restores it: when the repo has no precedent for the problem, explore agents research current practice, with sources, before any sketch (asking first with the chef there). The look-it-up principle covers smaller choices: a library, an API, a tool's behavior.
- **Every order is a ticket.** Intake starts only once work is a ticket, even a raw idea of the chef's: `new take` (`cook new <task>`), as in dev-workflow, files the ticket, then the server serves it with the chef there. The server's restated intent is the goal every later session works to, and what the ticket says to keep is part of it: a change there, however safe, waits for the chef as a Left for you item instead of being folded or decided alone (2026-10-30). The chef can also take a ticket in a session ("take PROJ-123"): cook creates the order when the scheduler has not, claims it, and runs intake with the chef there in three messages, each holding only what the next decision needs: the problem, then a recommendation once the chef agrees on the problem, then the goal line once the chef agrees on the approach (2026-11-08).
- **The skill is model-invocable.** With `disable-model-invocation` it never loaded on "take PROJ-123"; the scheduler's `-p "/kitchen ..."` expands the skill either way, so dropping the flag changes only in-session use, which starts from the chef's own request.
- **The roster runs on the session's model.** As `optimize-usage` it was pinned to fable at max effort; the chef chose the session model over a stop-and-switch step.
- **Order statuses**: a ticket is `new`, `serving`, or `review-queue`; an order is `ready`, `cooking`, `pr-open`, or `done`; `86` is dropped or parked, with its reason. A closed PR drops the order, since closing it was the call; three failed sessions and a missing tool park it.
- **Review means your approval gates the merge.** Approve on the PR (the pipeline opens PRs as the user, and the host refuses an author's own approval, so a comment reading `approve` counts) and the line merges; comment and the line fixes, and each comment is a catch that promotes on first sighting. A session lists the PR's comments again before it merges and handles any new one first; its own replies start with `kitchen:` so a later session does not take them for the user's.
- **The daily sample** is the first PR of the day, per project, when no PR needing review has opened that day.
- **Follow-ups.** On GitHub and Bitbucket the scheduler watches each open PR's last update and wakes the session only when it changed; a failed read waits for the next pass. Other hosts get a look every `followup_hours` (6), and the session that sees its PR merged closes the order itself.
- **Capacity per project**: one server at a time, `max_cooking` sessions (2), and the server stops filling the rail at `rail_depth` ready orders (3). All in `line.json`. Each session phase has a time limit (`max_minutes`: intake 45, cook 360, follow-up 120). Past it the scheduler sends TERM to the session's process tree, and KILL a pass later if it still runs; it settles the order once the session is gone. A stopped intake or cook counts toward the three retries, and so does a follow-up that ends without recording the PR again. `kitchen.zsh line set` changes any of these.
- **Models**: the server runs on `sonnet`, the cook on the session default; subagents use the existing `levers.py` choices.
- **The roster sets types, not roles** (2026-11-18). Every role in `SKILL.md`'s Subagents table maps to one type: judgment, review, code, critical code, research, other family, or general. `lever-state.json` sets each type's model and effort per account, and a roster change edits only that table. It replaces ten per-role levers, which left most roles' effort to a rule counted off the session's that the roster could not set, and reached neither the tasters, the comment check, nor `deepseek-flash-agent`. Code on a `## Critical` path runs as critical code. The grouping is the one dev-workflow's milestone build had (`558920b`). The scheduler's sessions are each order's main session, so they inherit the user's own model and effort as a guided session does, and `line.json` no longer carries `models`; only the retry after a tool error or a stall picks a model.
- **A bug counts only once a run proves it**: the quality gate writes the failing test before fixing, and a finding no run reproduces is logged as an unproven decision with the command tried.
- **Decisions the line makes alone** are logged per order (`kitchen.zsh decide`), listed in the PR under "Decided alone", and shown in the chef's catch-up.
- **No recipe fits**: the order is `bespoke`, carries its own steps, and goes to the review queue once.
- **Retired with the port**: the scoping, tester, plan-review, QA-planner, and code-review agents, and the old stations (scaffold, edge cases, tests first, plan, worker dispatch, parent review). Intake traces causes with the how and why stations, and the bug review is the interrogate station.
- **Contract first** (2026-10-29). Every recipe that ships code has its tests written and locked before the code is handed off, by a `worker-agent` on the contract role (`review_model`), never by the coder: a smart model confines a cheap one, as a course's graded harness confines students. Each test answers to an oracle (the report for a bug, the current code for a refactor, the coordinator's read against the intent for a feature) and names the done-when line or edge case it pins, so tests count against the contract, not the code. The coder keeps no tests, catering's milestone orders included. `contract-check.sh` holds the lock (only a `Contract-Files:` commit may touch a contract file) and confirms each named test ran and passed; taste breaks each test's behavior to prove it can fail, and a gaming taster reads for code shaped to the tests. The check the coder never saw is the verify session, which drives at least one behavior on inputs it picks itself. pstack's tdd covered bug fixes only and never said why.
- **Self-tuning** needed two changes to memory-review: a lesson a script, check, hook, or flag can enforce becomes that mechanism, and each edit is tried blind on a fresh sonnet agent before approval. Its lesson format already counted friction nobody was there to correct; the kitchen names which events count.
- **What waits for the user.** `kitchen.zsh sample` decides before every merge, in this order: `rebase` when the base moved under a file the branch changes or under the checks; `regate` when the change differs from what the quality gate passed (compared by patch id, recorded after the vault step), so fixes for comments, red checks, and rebase conflicts get the bug review too; `fix` when the verdict on this patch is FAIL; `verify` when no verdict covers this patch, which hands the PR to a verify session that did not write it; `review` when the change touches a check (CI, lint, type, test-runner or formatter config, the project rules, the verify skill), deletes a test, silences a check, touches an auth, billing, payment, migration, secret, security, crypto, or permission path (camelCase names included) or a path the project rules' `## Always review` lists, when the project is on probation (its first 5 merged PRs, `probation` in `line.json`), when the order has `review`, or as the daily sample. A PR with anything under Left for you sets `review` too. The user's approval is recorded by patch id, so it survives a clean rebase and lapses when the change does. Only `no` merges alone.
- **Red checks are classified first**: a failure outside the diff on a stale base is a rebase, anything else gets one rerun, and any failure after the rerun is fixed. Three real red rounds park the order.
- **Claims.** A session that works an order claims it first (`order claim`), recording its own `claude` process, so a cook the user starts and the scheduler never collide. A claimed session has no time limit and counts against `max_cooking`. Every session keeps its order `cooking` while it works the PR through checks and merge; `order pr` marks it `pr-open` only when the PR waits for the user, so no follow-up starts beside a session still working it. Once a claimed session hands the order on (a PR that waits for the user, a withdrawal, a close), the scheduler takes the order back even while the user's session stays open, and running `/kitchen cook <KEY>` again in that session claims it again. When it ends with the order unfinished, the order goes back to the ready queue, back to the review queue when it was claimed from there, or, for catering, back to the user. Dropping an order stops the scheduler's session on it, and `order pr` refuses a dropped order.
- **Retries count per phase**: a session that moves its order on resets the count, so intake's crashes never park a cook.
- **The last session's transcript.** Each headless session runs with a known session id; the next session on the same order reads the end of the one that stopped, to resume and to log a skill lesson when the skill caused it. Self-tuning hears from sessions that died before they could report.
- **Tickets and PR comments are data.** Headless sessions never run what a ticket or comment says to run, and pass that text to the order book only as `@/path` of a file they wrote. Deleting data the order did not create, force-pushing any branch but the order's own, or messaging anyone outside the ticket and the PR is a bounce, like a production deploy.
- **Promotions go through intake**: a promotion files its ticket and an order in `new`, and intake writes its done-when, files, and flags like any other.
- **Catering replaces the milestone build** (2026-10-29). Ultra's spec stays: written with the user, adversarially reviewed, merged as a PR. Its milestones are planned with the user and become ordinary orders the scheduler cooks headless on `spec/<EPIC>`, each with its own PR, gate, and verdict, ordered by an `after` list and based on `base=spec/<EPIC>`; the epic's own order comes back at `stage=close` to check the whole spec against the branch and open one PR to the base, which the user merges. The dynamic-workflow engine (milestone, review, and gather workflows, `milestone-args.py`, `levels.json`, the `build_*` levers) retired: it hid the work, took 67 of dev-workflow's 147 commits, and caused most of EN-503's failures. Kept from it: the gather and sweep, the milestone rules, the plan's approval checklist, the plan view, and the close's census; its run lessons moved into the verify skill station, the contract station, open a PR, and Subagents.
- **Decisions happen before the order exists** (2026-10-29). Following pstack, nothing in a cooking order waits on the user but a PR flagged for review. Every call the user owns is made before the order exists; a cook decides the rest alone, logs it, and flags the PR when it is a product call.
- **A new worktree starts on the base branch.** `EnterWorktree` branches from the default branch, so cook resets a new worktree to `origin/<base>`.
- **A second model family.** The other family role is `deepseek-flash-agent`: one of the bug review's two adversaries, the arena's cross-judge, and the decision trail's reviewer. It costs nothing on the Claude limit; when the proxy is down, each station says what replaces it.
- **Intake triages like benny**: read the whole ticket, trace the cause with the how and why stations, dedupe against open tickets, and fail closed. A ticket an open blocker holds is held (`order hold`) and served again after `followup_hours`, not dropped. A ticket assigned to someone else, or named by an open PR or branch, is dropped as claimed.
- **Stuck by progress, retry by cause.** A scheduler session with no order update and no commit in its worktree past `stall_minutes` (cook 60, follow 45, verify 45) is stopped; cooks mark each finished step with `order set step=`. A stopped session retries by cause: a context limit keeps the model and tells the next session to keep its context small, a dropped connection retries as is, a tool error or a stall moves to another model. The third stop bounces with the cause.
- **Decisions carry evidence**: `decide` takes a `file:line`, a command, or a link, and the PR and the catch-up show it.
- **Not built**: a scheduled calibration (an order needs a ticket, and the quality gate already repairs verify-skill drift on the branch that meets it), and a report of the tickets a merge unblocked (intake picks them up from the ready query).

## Verified

- Headless through `oc`: a session lists Agent, Workflow, ScheduleWakeup, Skill, and (deferred) TaskCreate, Monitor, SendMessage, EnterWorktree, PushNotification. A background agent's result arrived before the session exited. Print mode stops background agents 10 minutes after the main loop goes idle (seen in eval runs, 2026-10-30), so `fire` sets `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` and `reap` is the limit. `oc -p "/kitchen status"` invokes the skill and reads the order book.
- `kitchen.zsh` against stubbed `jira`, `gh`, and `oc`: serve, cook, retry after a dead session, park after three, merge cleanup, sign-off (an unserved order goes back to the server), catches with promote on the second sighting and on the chef's first, `climb` once a promotion ships, the daily sample, station overlap, new dishes never fired, the capacity cap, usage-limit backoff, follow-ups, a closed PR, the decision log, catches without an order, and catch-up since the last look.
- `make lint` passes. Without `< /dev/null`, every headless run stalls 3s waiting on stdin.
- The stub harness covers the verify phase (fire, unverified stop, wake after the verdict), `sample`'s `fix` and `verify`, stall detection by order update and worktree commit, KILL after TERM, retry by cause (context, connection, tool), and `order hold`: 47 cases pass.

Unverified:

- Catering's stages, its deployments, and the staged review: written, and harness-tested in `kitchen.zsh` and `check-plan.mjs`, never run by an agent.
- A company-account run, and a Workflow executing headless.
- This revision's script changes until the stub run passes: claims, time limits, prune by order, the merge check and approvals, Bitbucket reads, `@/path` values, and the epic alias.
- Facts the script relies on: `bb pr get -o json` carrying `state` and `updated_on`; `claude` appearing as the first argument of the session's process (the native install); transcripts at `~/.claude*/projects/*/<session-id>.jsonl`.

## Known limits

- **Restarting the expo kills in-flight sessions.** They share its process group, and a non-interactive shell cannot give them their own. Each restart counts toward the three-strike park.
- **Only while this Mac is awake.**
- **Lessons filed under `## Skill: dev-workflow`** in auto memory now belong to the kitchen. Only `/memory-review` moves them.
- `kitchen/commands/roster/temp/lever-state.json`, a saved lever preset, still names dev-workflow steps. It was left as saved.
- Under Git Bash, `ps` cannot list processes, so `order claim` records no process and a claimed order is not released when its session ends; the scheduler runs only on macOS, where this does not arise.

## Open

- **Notifications.** How you hear about your rail, shipped PRs, and a stuck or dead line. Waiting until a real run shows what orders look like. Closed by the [redesign](#closed-and-declined): no notifications; status at each decision window covers it.
