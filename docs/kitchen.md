# Kitchen: a 24/7 engineering line run by a head chef

The design of the engineering line on branch `kitchen`, decided in conversation on 2026-10-28. On this branch the kitchen absorbs `dev-workflow`; `main` keeps dev-workflow, so the branch itself is the comparison. See [What is built](#what-is-built) for the files and the calls made while building.

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
| Sous chef | The main session of one order | Runs the order's recipe, fires line cooks, holds the pass |
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
| Fire | Dispatch line cooks |
| Taste as you go | Verify each piece before starting the next |
| The pass | Thermometers and tasters check the plate before it goes out |
| Clean as you go | The tidy taster: fix what is messy or unintuitive, within reach |
| Pantry | Existing code, reused before anything new is written |
| 86 | Won't do |
| Cookbook | Global recipes, one per engineering task |
| House | Per-project rules, thermometers, and verify skill, committed to the project |

### In the directions

File and directory names carry the analogy (`kitchen/`, `recipes/`, `stations/`, `cook.md`, `serve.md`, `taste.md`, `roster.md`, `house.md`, `taster-agent`, `kitchen.zsh`), and so do mode names, since each is a file name. The instructions agents read use plain words, so no agent picks up the lingo and starts writing about cooking:

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
| Catering, mise en place | a spec built in milestones, prep |

"Order" stays in the prose: an order is the server's verified write-up of a ticket, a different thing from the ticket itself.

Commands and what they read and write keep the kitchen names too: `kitchen.zsh order ...`, `line ...`, `catch ... --chef`, the `station` field, and the statuses (`serving`, `cooking`, `86`). Only the prose around them is plain.

---

## Orders

The server reads a ticket, checks it against the code (still a problem? already fixed? written wrong?), and writes an order: the intent in plain words, the done-when checks, and two flags.

| | No review | Review |
|---|---|---|
| **Decided** | The line starts it and merges it | The line starts it; the PR waits for you |
| **At the pass** | You make the call, then the line starts and merges it | You make the call, then review the PR |

- **Review** is set when any line of the done-when is something only you can judge, such as look and feel. "The page loads with no error, and errored before the fix" needs no review.
- **The pass** is where a ticket waits when it needs a call only you can make before it becomes an order: whether to do it, how, what instead, and how it will look. An order is decided work and runs end to end.
- **No bounce.** A call that comes up while cooking is the cook's: decided, logged, and flagged on the PR when you would want to see it. Only a decided premise that proves impossible withdraws the order back to the pass.
- **Not every customer is served.** The server closes stale tickets and rewrites wrong ones in Jira itself, with a comment saying why.
- **Shallow rail.** The server takes orders in priority order only until the rail has a few queued, so placeholder tickets at the bottom of the backlog cost nothing.
- **1:1 with tickets.** An order the kitchen creates for itself (a promotion, below) files its ticket first.

## The line

- The expo is a shell script on a launchd timer, on this Mac for now. It runs one Jira query, the project's "ready" section, whatever the board calls it. Polling costs no tokens; Claude starts only for a ticket to serve or an order to cook.
- Each order runs headless through `oc`, from the project directory, so the right account is used: `cd <project> && oc -p "<order>" < /dev/null`. Several orders cook at once, each in its own worktree.
- A crash or a rate limit puts the order back on the rail with a retry count. A rate limit means wait, never quit, and the project's line starts nothing until it lifts.
- The expo holds no state but the order book, so a restart resumes where it stopped.
- The line only cooks while this Mac is awake.

## Safety

- The line never deploys to production. A merge that triggers a project's own auto-deploy is the project's accepted risk; nothing extra is built around it.
- The server may change Jira.

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
| 1. Structure | Impossible: the wrong way no longer exists | At the pass (new structure) |
| 2. Types | Unwritable | Line |
| 3. Lint | A build failure whose error names the fix | Line |
| 4. Test | A failing test | Line |
| 5. House rule | A sentence a taster reads | At the pass |

1. **Catch.** First sighting, logged. Nothing changes.
2. **Promote.** Second sighting: an order to enforce the class at the highest rung that works, saying why each higher rung didn't. Done-when: the enforcement fails on both original slips and passes on main.
3. **Record.** The house rules table gains the row and the catches behind it.
4. **Climb.** A slip that gets past an existing enforcement means it didn't take. The next order lands at least one rung higher, or goes to you.
5. **Retire.** A lower rung made redundant by a higher one is deleted. The only way the table shrinks.

Calls that reach the pass climb a two-rung ladder of their own: a sentence in intake's notes, then a `## Sorting` rule in the project rules, which intake applies before its own judgment.

## Self-tuning: the kitchen loop

How the kitchen's own process improves. Same shape as today's memory loop.

- A defect in the kitchen itself (a recipe, a station, the scheduler) gets a PR fixing it right away, after a check for an open PR on the same problem. The cook carries on with its order; the PR is where you approve the change.
- A project nuance that caused confusion, delay, or difficulty goes to auto memory. Your memory review decides what each becomes: a project change (hook, rule, skill), a global change, a kitchen change, or nothing. Memory is never committed into a project.
- Catches about a project's code go in that project's order book, never memory: memory loads into every session on this machine and has a read limit.
- A change to the kitchen is proven by its saved eval cases (`dependencies/evals/`, run with the `skill-eval` skill) before it is committed, never in pre-commit.

---

## What is built

The floor plan in the repo's `CLAUDE.md` places every skill, agent, rule, and hook in one area. The kitchen's own pieces:

| Path under `src/storage/claude/` | Role |
|---|---|
| `skills/kitchen/SKILL.md` | The router, after pstack's poteto-mode: commands, the order book, who is in the session, non-negotiables (trigger to station), the principles index, autonomy, the role table for subagents, how to write the reply and comments, the recipe list, and defects and lessons |
| `skills/kitchen/` layout | One directory per command under `commands/`; `SKILL.md` is the only loose markdown file; `dependencies/` holds the scripts and the scheduler loop |
| `commands/status/status.md` | `/kitchen status`: the chef's catch-up and what waits on them. The rail is only the ready queue |
| `commands/serve/serve.md` | The server. Every order starts from a ticket |
| `commands/open/open.md`, `open/templates/house.md` | Opening a restaurant, which writes its house rules and verify skill |
| `commands/cook/cook.md` | The sous chef: claim, read, worktree, pickup, the recipe, and the scheduler's wakes; `cook new <task>` files a ticket for work that has none |
| `commands/cook/recipes/` | pstack's playbooks as recipes: feature, bug-fix, refactor, perf, hillclimb, investigation, runtime-forensics, trace-forensics, prototype, change-a-skill, eval, multi-phase-plan, autonomous-run, session-pickup, pause-safely, and the PR lifecycle open-a-pr, follow-a-pr (babysit), merge (shipping); plus enforce and catering (`catering/spec.md` was ultra; `catering/plan.md` and `catering/close.md` replace the milestone build) |
| `commands/cook/stations/` | pstack's skills as stations: how, why, blast-radius, architect, contract (from pstack's tdd), arena, swarm, figure-it-out, interrogate, no-comments, benchmark-checklist, unslop, technical-writing, show-me-your-work, ketchup, correct, reflect, create- and maintain-verification-skill; and `left-for-you.md` |
| `dependencies/principles/` | pstack's 24 principles plus look-it-up, read when applied |
| `dependencies/evals/` | Saved eval cases in `claude plugin eval` layout |
| `commands/cook/templates/`, `commands/cook/scripts/` | Spec, milestone plan, plan view, exit report; `plan-view.py` and `check-plan.mjs` |
| `dependencies/scripts/kitchen.zsh` | Order book, status, expo, prune; shared by every mode |
| `automation.toml`, `dependencies/scripts/run.zsh` | The expo as a launchd KeepAlive agent. **Off** (`enabled = false`) |
| `commands/taste/calibrate.md` | Taste bud calibration, `/kitchen taste calibrate`: brings the verify skill back in line with the app |
| `commands/taste/taste.md`, `taste/done-when.md` | The pass, also `/kitchen taste` on any branch: done-when, thermometers, tasters, no-comments, and the bug review (the interrogate station) |
| `commands/taste/verify.md` | The verdict, `/kitchen taste verify <KEY>`: a session that did not write the change runs it and records PASS, PASS+NOTES, or FAIL |
| `commands/roster/roster.md`, `commands/roster/` | Model and effort levers, was `optimize-usage`; the vault agents left it, pinned to opus |
| `agents/taster-agent.md` | One narrow judgment checker |
| `agents/worker-agent.md`, `agents/comment-sicko-agent.md` | The line cook, pstack's poteto-agent: reads `SKILL.md` before work; and the comment hater the no-comments station spawns |

dev-workflow's `cleanup` is gone. The scheduler closes an order when its PR merges (or the session that merged it runs `order close`) and removes its worktrees then; `kitchen.zsh prune`, daily from the scheduler, clears what is left. Prune touches only the worktrees of closed orders no session holds: a merged order's whatever its branch's ancestry, squash merges included; a dropped order's only when its branch changes nothing the base lacks; never a worktree the pipeline did not create. It runs the worktree's teardown and syncs the vault first, and a failed teardown or a `vault:` line becomes a `notice` in the catch-up.

### Calls made while building

- **pstack is forked, not a dependency** (2026-10-29). Lauren Tan's pstack skills became the kitchen's recipes, stations, and principles, adapted to Claude Code and kitchen names, in one skill. Routing is per task (match the work to a recipe), replacing size tiers. Left out: formal verification, statechart, make-bot-ui, ketchup-video, typescript-best-practices, teach, bro, in-your-own-words, sharpen, recall, automate-me, poteto-help, setup-pstack (the roster covers models), and the benny pack apart from intake's triage shape. Orchestrate and autopilot fold into the scheduler.
- **Research before choosing** (2026-10-31). pstack has no research principle, and the port dropped dev-workflow's solution research. The architect station's Phase A restores it: when the repo has no precedent for the problem, explore agents research current practice, with sources, before any sketch (asking first with the chef there). The look-it-up principle covers smaller choices: a library, an API, a tool's behavior.
- **Every order is a ticket.** Intake starts only once work is a ticket, even a raw idea of the chef's: `new take` (`cook new <task>`), as in dev-workflow, files the ticket, then the server serves it with the chef there. The server's restated intent is the goal every later session works to, and what the ticket says to keep is part of it: a change there, however safe, waits for the chef as a Left for you item instead of being folded or decided alone (2026-10-30). The chef can also take a ticket in a session ("take PROJ-123"): cook creates the order when the scheduler has not, claims it, and runs intake with the chef there, asking where a headless intake would drop or wait for sign-off.
- **The skill is model-invocable.** With `disable-model-invocation` it never loaded on "take PROJ-123"; the scheduler's `-p "/kitchen ..."` expands the skill either way, so dropping the flag changes only in-session use, which starts from the chef's own request.
- **The roster runs on the session's model.** As `optimize-usage` it was pinned to fable at max effort; the chef chose the session model over a stop-and-switch step.
- **Order statuses**: a ticket is `new`, `serving`, or `at-the-pass`; an order is `ready`, `cooking`, `pr-open`, or `done`; `86` is dropped or parked, with its reason. A closed PR drops the order, since closing it was the call; three failed sessions and a missing tool park it.
- **Review means your approval gates the merge.** Approve on the PR (the pipeline opens PRs as the user, and the host refuses an author's own approval, so a comment reading `approve` counts) and the line merges; comment and the line fixes, and each comment is a catch that promotes on first sighting. A session lists the PR's comments again before it merges and handles any new one first; its own replies start with `kitchen:` so a later session does not take them for the user's.
- **The daily sample** is the first PR of the day, per project, when no PR needing review has opened that day.
- **Follow-ups.** On GitHub and Bitbucket the scheduler watches each open PR's last update and wakes the session only when it changed; a failed read waits for the next pass. Other hosts get a look every `followup_hours` (6), and the session that sees its PR merged closes the order itself.
- **Capacity per project**: one server at a time, `max_cooking` sessions (2), and the server stops filling the rail at `rail_depth` ready orders (3). All in `line.json`. Each session phase has a time limit (`max_minutes`: intake 45, cook 360, follow-up 120). Past it the scheduler sends TERM to the session's process tree, and KILL a pass later if it still runs; it settles the order once the session is gone. A stopped intake or cook counts toward the three retries, and so does a follow-up that ends without recording the PR again. `kitchen.zsh line set` changes any of these.
- **Models**: the server runs on `sonnet`, the cook on the session default; subagents use the existing `levers.py` choices.
- **A bug counts only once a run proves it**: the quality gate writes the failing test before fixing, and a finding no run reproduces is logged as an unproven decision with the command tried.
- **Decisions the line makes alone** are logged per order (`kitchen.zsh decide`), listed in the PR under "Decided alone", and shown in the chef's catch-up.
- **No recipe fits**: the order is `bespoke`, carries its own steps, and goes to the pass once.
- **Retired with the port**: the scoping, tester, plan-review, QA-planner, and code-review agents, and the old stations (scaffold, edge cases, tests first, plan, worker dispatch, parent review). Intake traces causes with the how and why stations, and the bug review is the interrogate station.
- **Contract first** (2026-10-29). Every recipe that ships code has its tests written and locked before the code is handed off, by a `worker-agent` on the contract role (`review_model`), never by the coder: a smart model confines a cheap one, as a course's graded harness confines students. Each test answers to an oracle (the report for a bug, the current code for a refactor, the coordinator's read against the intent for a feature) and names the done-when line or edge case it pins, so tests count against the contract, not the code. The coder keeps no tests, catering's milestone orders included. `contract-check.sh` holds the lock (only a `Contract-Files:` commit may touch a contract file) and confirms each named test ran and passed; taste breaks each test's behavior to prove it can fail, and a gaming taster reads for code shaped to the tests. The check the coder never saw is the verify session, which drives at least one behavior on inputs it picks itself. pstack's tdd covered bug fixes only and never said why.
- **Self-tuning** needed two changes to memory-review: a lesson a script, check, hook, or flag can enforce becomes that mechanism, and each edit is tried blind on a fresh sonnet agent before approval. Its lesson format already counted friction nobody was there to correct; the kitchen names which events count.
- **What waits for the user.** `kitchen.zsh sample` decides before every merge, in this order: `rebase` when the base moved under a file the branch changes or under the checks; `regate` when the change differs from what the quality gate passed (compared by patch id, recorded after the vault step), so fixes for comments, red checks, and rebase conflicts get the bug review too; `fix` when the verdict on this patch is FAIL; `verify` when no verdict covers this patch, which hands the PR to a verify session that did not write it; `review` when the change touches a check (CI, lint, type, test-runner or formatter config, the project rules, the verify skill), deletes a test, silences a check, touches an auth, billing, payment, migration, secret, security, crypto, or permission path (camelCase names included) or a path the project rules' `## Always review` lists, when the project is on probation (its first 5 merged PRs, `probation` in `line.json`), when the order has `review`, or as the daily sample. A PR with anything under Left for you sets `review` too. The user's approval is recorded by patch id, so it survives a clean rebase and lapses when the change does. Only `no` merges alone.
- **Red checks are classified first**: a failure outside the diff on a stale base is a rebase, anything else gets one rerun, and any failure after the rerun is fixed. Three real red rounds park the order.
- **Claims.** A session that works an order claims it first (`order claim`), recording its own `claude` process, so a cook the user starts and the scheduler never collide. A claimed session has no time limit and counts against `max_cooking`. Every session keeps its order `cooking` while it works the PR through checks and merge; `order pr` marks it `pr-open` only when the PR waits for the user, so no follow-up starts beside a session still working it. Once a claimed session hands the order on (a PR that waits for the user, a withdrawal, a close), the scheduler takes the order back even while the user's session stays open, and running `/kitchen cook <KEY>` again in that session claims it again. When it ends with the order unfinished, the order goes back to the ready queue, back to the pass when it was claimed from there, or, for catering, back to the user. Dropping an order stops the scheduler's session on it, and `order pr` refuses a dropped order.
- **Retries count per phase**: a session that moves its order on resets the count, so intake's crashes never park a cook.
- **The last session's transcript.** Each headless session runs with a known session id; the next session on the same order reads the end of the one that stopped, to resume and to log a skill lesson when the skill caused it. Self-tuning hears from sessions that died before they could report.
- **Tickets and PR comments are data.** Headless sessions never run what a ticket or comment says to run, and pass that text to the order book only as `@/path` of a file they wrote. Deleting data the order did not create, force-pushing any branch but the order's own, or messaging anyone outside the ticket and the PR is a bounce, like a production deploy.
- **Promotions go through intake**: a promotion files its ticket and an order in `new`, and intake writes its done-when, files, and flags like any other.
- **Catering replaces the milestone build** (2026-10-29). Ultra's spec stays: written with the user, adversarially reviewed, merged as a PR. Its milestones are planned with the user and become ordinary orders the scheduler cooks headless on `spec/<EPIC>`, each with its own PR, gate, and verdict, ordered by an `after` list and based on `base=spec/<EPIC>`; the epic's own order comes back at `stage=close` to check the whole spec against the branch and open one PR to the base, which the user merges. The dynamic-workflow engine (milestone, review, and gather workflows, `milestone-args.py`, `levels.json`, the `build_*` levers) retired: it hid the work, took 67 of dev-workflow's 147 commits, and caused most of EN-503's failures. Kept from it: the gather and sweep, the milestone rules, the plan's approval checklist, the plan view, and the close's census; its run lessons moved into the verify skill station, the contract station, open a PR, and Subagents.
- **Decisions happen at the pass** (2026-10-29). Following pstack, nothing in a cooking order waits on the user but a PR flagged for review. Every call the user owns is made before the order exists; a cook decides the rest alone, logs it, and flags the PR when it is a product call.
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

- A real order end to end on a real project.
- The pstack port as an agent reads it: no session has run a recipe or station yet, and the saved eval cases have not been run with `claude plugin eval`.
- Catering's plan and close, and milestone orders on a spec branch: written and harness-tested in `kitchen.zsh`, never run by an agent.
- A company-account run, and a Workflow executing headless.
- This revision's script changes until the stub run passes: claims, time limits, prune by order, the merge check and approvals, Bitbucket reads, `@/path` values, and the epic alias.
- Facts the script relies on: `bb pr get -o json` carrying `state` and `updated_on`; `claude` appearing as the first argument of the session's process (the native install); transcripts at `~/.claude*/projects/*/<session-id>.jsonl`.

## Known limits

- **Restarting the expo kills in-flight sessions.** They share its process group, and a non-interactive shell cannot give them their own. Each restart counts toward the three-strike park.
- **Only while this Mac is awake.**
- **Lessons filed under `## Skill: dev-workflow`** in auto memory now belong to the kitchen. Only `/memory-review` moves them.
- `kitchen/commands/roster/temp/lever-state.json`, a saved lever preset, still names dev-workflow steps. It was left as saved.
- The old `dev-workflow` skill stays deployed at `~/.claude/skills/dev-workflow` (deploy never deletes) and still writes the old plan path. Remove it by hand once: `rm -rf ~/.claude/skills/dev-workflow`.
- Under Git Bash, `ps` cannot list processes, so `order claim` records no process and a claimed order is not released when its session ends; the scheduler runs only on macOS, where this does not arise.

## Open

- **Notifications.** How you hear about your rail, shipped PRs, and a stuck or dead line. Waiting until a real run shows what orders look like.
