# Workspace type: Brazil

A Brazil project is a team's parent Brazil workspace, one directory with no `.git` that holds the team's packages. Nothing builds in it, so the version set `brazil ws use` gives it when it has none never matters. Each package is its own git repository, and an order gives each package it changes its own base branch. An order works in a `brazil worktree` of the workspace, pinned to one version set, and opens one CR across the packages it changed.

`kitchen.zsh workspace` prints this file's path on a line registered with `--workspace brazil`. Each section below names the kitchen file and the steps it replaces or adds to. Take those steps from here, and every other step as its own file says.

## What is where

| Path | What it is |
| --- | --- |
| `<ws>` | The project, such as `~/dev/amz/Robogami`. Not a git repository. Holds `.claude/kitchen/house.md`, `.claude/ticket-provider/`, and one verify skill per package in `.claude/skills/verify-<package>/`, which no branch can change and no commit records. |
| `<ws>/src/<Pkg>` | The parent checkouts, shared by every order. Never edit, build in, or switch branches in one. |
| `<ws>/worktrees/<KEY>` | The order's worktree, a Brazil workspace pinned to the order's `version_set`. Its `src/<Pkg>` are git worktrees of the parent checkouts, each on a branch named `<KEY>` that tracks `origin/<base>`. Not a git repository itself. |
| `<ws>/worktrees/verify-<KEY>` | The verifier's worktree. It holds the same packages, each detached at the head of the order's branch. |

A package's base is the branch its major version in the order's version set builds from. It differs between packages and between version sets: ARManipulationUWCCDKCommon 1.1 builds from `testing` and 1.0 from `1.0`, and ARCardinalUWCCDK builds from `mainline`. In this file `<wt>` is the order's worktree, `<Pkg>` is a package, and `<base>` is that package's base.

A session uses these commands from any directory under `<ws>`:

| Command | Does |
| --- | --- |
| `kitchen.zsh workspace enter <KEY> [NAME]` | Makes worktree `NAME` (default `<KEY>`) match the order, creating or repairing it, and prints its path. Safe to repeat. |
| `kitchen.zsh workspace check <KEY>` | Prints one row per package: its base, what its branch tracks, commits ahead, and dirty files. Exits 1 when a package cannot go into a CR. Warns when a parent checkout is dirty or off its branch. |
| `kitchen.zsh workspace bases <KEY>` | Prints the order's packages and their bases. `kitchen.zsh order base <KEY>` refuses on this line, since there is no single base. |
| `kitchen.zsh each <KEY> [--changed] -- <command>` | Runs the command once in each package of the worktree the current directory lies in, else of the order's own, from the package's directory with `BASE` set to its base. `--changed` skips a package with no commit past its base. Each run's output is headed `== <Pkg>`, and the exit code is the worst run's. |

## Open

Read this before [open](../../commands/open/open.md) step 1. Each step here replaces the step of open with its number.

1. **Equipment.** Steps 1 and 2 read the team's packages, so on a fresh workspace first check out the ones the team changes most with `brazil ws use -p <Pkg>` at `<ws>`. The tracker's config lives at `<ws>/.claude/ticket-provider/`. Run the ticket-provider skill's setup from `<ws>`. Where it reads a ticket key from the commit log, read it from one of the team's packages (`git -C <ws>/src/<Pkg> log -200 --format=%B`). Skip its `info/exclude` step, since `<ws>` is not a repository. `ticket.zsh provider` then works from `<ws>` and from every directory under it. Run the `git-provider` skill's pre-flight from one package's directory, `<ws>/src/<Pkg>`. Skip the `order base -` check, since each order picks a base per package.
2. **Project rules** go to `<ws>/.claude/kitchen/house.md`, from the template, with these changes.
   - Find the mistake classes in the merged CRs and commit logs of the packages the team changes most.
   - `Gate` is decided with the user as open step 2 says, for a single package: one command run from a package's directory, fastest check first, ending in `brazil-build release`. A script for it goes in the line's order book directory, outside every package. [The gate](#the-gate-per-package) runs it in every package of an order. Confirm it in one package the team changes most, since cook step 5 runs it on every order's untouched worktree.
   - `Mutation` is one line for every package, and the sweep fails in a JavaScript or TypeScript package that lacks Stryker. Record Stryker only once every such package the team changes has it installed. Otherwise record `off:` and why.
   - The Critical paths regexes are relative to a package's root and apply in every package, as in one repository. A rule meant for one package says so with a path only that package has.
   - The file is in no git repository, so there is no base-branch copy, and `kitchen.zsh rules` reads this one file.
3. **The verify skills.** Every package in `<ws>/src` gets a verify skill of its own at `<ws>/.claude/skills/verify-<package>/`, outside every repository, so none is committed and a session at `<ws>` loads them all. Write each per the [create a verification skill](../../commands/cook/stations/create-verification-skill.md) station, driving the package in a `brazil worktree` of its own, never in `<ws>/src`. Each takes the package directory of a worktree as its input, so it drives an order's head and its base alike. A package checked out later gets its skill then.
4. **Register** with `kitchen.zsh line add <ws> --workspace brazil`, which prints the slug. The path can be any directory under `<ws>`, a worktree's included, and running it again changes nothing. The command accepts a workspace fresh from `brazil ws create`, before any package is checked out. A package inside `<ws>` is never its own line. Once `<ws>` is registered, `line add` without `--workspace` refuses any directory inside it. When a line already exists for a directory inside `<ws>`, `line add <ws> --workspace brazil` refuses too. Each refusal names the other line. What to do with that line is the user's call, since `kitchen.zsh line rm <slug>` deletes its orders with it. Then run `kitchen.zsh line set <slug> max_cooking=1`. Whether two `brazil-build` runs in two worktrees at once share state outside their worktrees is unverified, so keep one order cooking until two have built at once without a failure.
5. **Tell the user** as open step 5 says, with two changes. Each order records a base per package. The project rules are a file the user owns, in no repository.

## Intake

Adds to [serve](../../commands/serve/serve.md) steps 2, 3, 5, 6, and 7.

- **Step 2.** `<ws>` is not a repository, so check that nobody has started the ticket from each package's directory, `<ws>/src/<Pkg>`, once step 5 names the packages.
- **Step 3, reading code.** A package the reading needs that `<ws>/src` lacks is checked out with `brazil ws use -p <Pkg>` at `<ws>`. Read another branch with `git -C <ws>/src/<Pkg> show origin/<branch>:<path>`, never by switching the parent checkout.
- **Step 5, the packages.** Name every package whose files the agreed scope touches, as far as step 3's reading shows, each by its Brazil package name. Cook step 10 adds one found later.
- **Step 5, the version set and each base.** The package's release summary, `https://code.amazon.com/packages/<Pkg>/releases`, lists the version sets that consume each major version. Pick the one version set the ticket's product runs in. `brazil vs print --versionSet <set>` gives the package's version in it. That version's page, `https://code.amazon.com/packages/<Pkg>/releases/<version>`, read with `ReadInternalWebsites`, names the branch the build came from, and that branch is the package's base. Never default a base to `mainline`, since one order can mix bases.
- **Step 5, the recipe.** Never pick `catering`. Its staged review needs `kitchen.zsh stage`, which refuses this line, so tell the user when only catering fits. Packages that need two version sets make the ticket a `multi-phase-plan`, with one child ticket and order per version set, each `after` the one before. An order has one worktree and one CR.
- **Step 6.** Send the version set and each base with the recipe, each with the release page lines that settle it. A base or version set the page does not settle is the user's call, asked here.
- **Step 7.** Write the two fields with the rest of the order:

        kitchen.zsh order set <KEY> version_set=<Group>/<Name> packages=@<file> station=@<file> ...

  `packages` is a JSON object, `{"<Package>": "<base>"}`. `station` entries are `<Package>/<path>`, a directory with a trailing `/`, and a whole package as `<Package>/`. They stay plain prefixes, so two orders overlap when one entry starts with the other. Every package `station` names must also be in `packages`, since the worktree holds only the packages `packages` lists.

## Cook

Replaces [cook](../../commands/cook/cook.md) steps 5 and 6, and adds to step 10.

5. **Enter the order's worktree.** `kitchen.zsh workspace enter <KEY>` creates it from the order's `version_set` and `packages`, or repairs it, and prints `<wt>`. Each package's branch is `<KEY>`, on its own base and tracking it. A package that keeps a local knowledge vault gets it there, and enter prints a `vault:` line saying so. Work by absolute path under `<wt>/src/<Pkg>/`, and `cd` there in each command. Never use `EnterWorktree`, which enters one git repository. Then run the Gate once on the untouched worktree, as [The gate](#the-gate-per-package) says. Red there means a package's base does not match the version set, or a base fails on its own. On an `auto` order, park it with `kitchen.zsh order set <KEY> status=86 "reason=parked: the Gate fails on the untouched worktree, so a package's base may not match the version set"`. Otherwise tell the user. Once a base in `packages` is corrected, run `kitchen.zsh workspace enter <KEY>` again: a package with no commits of the order's own moves onto its new base, and one with commits stays and is named.
6. **On a pickup**, the trail is `kitchen.zsh workspace check <KEY>` and `kitchen.zsh each <KEY> --changed -- git --no-pager log --oneline origin/\$BASE..HEAD`. A package with dirty files gets its own `wip: <step>` commit.
10. **Before changing a package the order lacks**, read its base from its release page as intake does. Add it with `kitchen.zsh order set <KEY> packages=@<file> station=@<file>`, then run `kitchen.zsh workspace enter <KEY>`, which adds the package and never removes one. A package new to `<ws>/src` gets its verify skill first, per [Open](#open) step 3. A package in the worktree with no entry in `packages` makes every gate command refuse, so no gate can skip it. When the worktree lacks a package that `packages` lists, `kitchen.zsh each`, `workspace check`, `order gated`, and `sample` fail and name it, until `kitchen.zsh workspace enter <KEY>` adds it.

The contract station commits each package's tests in that package's own repository, and the contract check reads each package as it reads one repository, a manual order's included.

On a manual order, `kitchen.zsh handoff <KEY>` opens `<wt>` itself in VS Code, so the user sees every package of the order in one window. On a co-write order, show a piece with `git --no-pager -C <wt>/src/<Pkg> show <commit>`, and record it as `agreed=<Pkg> <commit> <what the piece is>`.

## The gate, per package

Replaces how [taste](../../commands/taste/taste.md) step 1, [open a PR](../../commands/cook/recipes/open-a-pr.md) step 4, and [verify](../../commands/taste/verify.md) step 3 run their checks. Write `\$BASE` as shown, so each run of `kitchen.zsh each` expands it to its own package's base.

- **The contract held.** `kitchen.zsh each <KEY> --changed -- bash ~/.claude/skills/kitchen/dependencies/scripts/contract-check.sh origin/\$BASE --run`.
- **Every changed line has a test.** From clean trees, `KITCHEN_RULES=<ws>/.claude/kitchen/house.md kitchen.zsh each <KEY> --changed -- python3 ~/.claude/skills/kitchen/dependencies/scripts/mutation-sweep.py origin/\$BASE`. `KITCHEN_RULES` is how the sweep finds the Mutation line, which sits above the package. The file `KITCHEN_RULES` names wins over a `.claude/kitchen/house.md` that a package commits, such as one left from when the package was a kitchen project of its own.
- **On a manual order**, the sweep's `--test-cmd` is each package's own, so run it once per package with commits, from `<wt>/src/<Pkg>`, instead of through `kitchen.zsh each`.
- **The Gate** runs once for the order, from `<wt>/src`, as `brazil-recursive-cmd --allPackages <the Gate command>`. That runs the command in every package of the worktree in dependency order, each built against the worktree's copies of the others. A package on the wrong base fails there.
- **After any build**, `brazil-build` has rewritten `package-lock.json` in an npm package. In each package where `kitchen.zsh workspace check <KEY>` shows dirty files, run `git -C <wt>/src/<Pkg> restore package-lock.json`, unless the order means to change it. The sweep, the fold, and cleanup all refuse a dirty tree.
- **Tasters** get one diff range per package with commits, `origin/<base>..HEAD` in `<wt>/src/<Pkg>`, each labelled with its package. A finding names its package, and `kitchen.zsh catch` takes it as written.

## Open a PR

Replaces steps 3 to 5 of [open a PR](../../commands/cook/recipes/open-a-pr.md).

3. **Record the gate.** Do the vault step as open a PR step 3 says. Then run `kitchen.zsh order gated <KEY>` once. It stores one id over every package, and `gated_head` and `gated_base` as one `<package>: <sha>` row per package.
4. **Fold each package, then run the Gate once.**
   1. With every tree clean, run the contract check as [The gate](#the-gate-per-package) says. It must not report the contract broken in any package. It names each package's latest contract commit.
   2. In each package with commits, fold as open a PR step 4.2 says, against that package's base. The subject is the PR's title in every package, so the CR reads as one change. The trailers are that package's own latest contract trailers.
   3. In each of those packages, `git rebase origin/<base>`.
   4. Run the Gate once, as The gate says, then restore `package-lock.json`. On red, fix as open a PR step 4.4 says, in the package that failed. On green, push through the `git-provider` skill's Push in its several-package form, which does nothing before the CR exists.
5. **Open one CR.** `kitchen.zsh workspace check <KEY>` must exit 0, so every package tracks its own base. Run the `git-provider` skill's host detection from a package directory, since `<wt>/src` and `<ws>` are not repositories. Create the CR through that skill's Create PR in its several-package form. The description names the version set, and gives each package a heading with what changed in it and its base. Record the CR with `kitchen.zsh order set <KEY> pr=<url>`, and move the ticket with the `review` moment. When that skill falls back to one CR per base, record the last one in its stack order as `pr`, since CRUX merges it only after every CR before it ships. Each description then lists every CR of the order.

## Verify

Replaces [verify](../../commands/taste/verify.md) step 2, and adds to steps 3, 4, 8, and 9.

2. **Check out the CR head on your own.** `kitchen.zsh workspace enter <KEY> verify-<KEY>` prints `<vw>`. Each package there is detached at the tip of the order's branch in `<wt>`, which is the head the CR holds.
3. Run the contract check and the Gate as [The gate](#the-gate-per-package) says, from inside `<vw>`, so `kitchen.zsh each` runs in its packages and not the order's.
4. Drive the change through the verify skill of each package it changed, `<ws>/.claude/skills/verify-<package>/`, in `<vw>/src/<Pkg>`, and the done-when lines through whichever of them each line names.
8. Run `kitchen.zsh order verdict <KEY> ...` from any directory inside `<vw>`. The heads match the author's, so the verdict's id matches the change, and `sample` asks for no second verdict.
9. Leave `<vw>` where it is, with no `ExitWorktree`. Cleanup removes it with the order.

## Merge and follow

Adds to [merge](../../commands/cook/recipes/merge.md) and [follow a PR](../../commands/cook/recipes/follow-a-pr.md).

- `kitchen.zsh sample <KEY>` and `kitchen.zsh order approve <KEY> HEAD` work from any directory under `<ws>`. They read the order's worktree unless the directory lies inside another one.
- **Approval.** On this line `order approve` takes only `HEAD`, which records each package's current head, and refuses any other commit. Where merge step 4 or follow a PR step 4 records the user's approval, run it the moment they approve, before any later commit. In follow a PR, that is before step 3 commits anything. If any package has a commit since the revision they approved, record no approval, since `HEAD` is no longer the change they approved.
- **`rebase`.** A package's base moved under it. Fold and rebase that package and run the Gate as [Open a PR](#open-a-pr) step 4 says. Then update the CR with the `git-provider` skill's Push in its several-package form. Every package already in the CR must stay in the update.
- **`regate`.** Run the Gate as [The gate](#the-gate-per-package) says. Then run the sweep and merge's `git range-diff` once per package with commits, from `<wt>/src/<Pkg>`, with that package's rows of `gated_base` and `gated_head`, the sweep taking `--since` that package's `gated_head` row.
- **Close.** Merge step 4's cleanup skips `ExitWorktree`, since the session entered no worktree. `prune` prints `removed <Pkg> (<KEY>)` for each package, then `removed <KEY>`.
- **Merge** is the `git-provider` skill's Merge in its several-package form. CRUX merges all of a CR's packages or none, so a conflict in one package holds the whole CR until that package is rebased and pushed.
- **One CR per base.** When the order has several CRs, Push and Merge run once per CR as the `git-provider` skill says, and a follow pass reads the comments and checks of every CR the description lists, not only `pr`.
- **A comment, a red check, or a `FAIL`** is fixed as follow a PR says, in the package it names.
- **The user's review** step 1 enters no worktree. Work under `<wt>` by absolute path.

## Cleanup

`kitchen.zsh prune` and the scheduler's daily pass land a closed order's worktree one package at a time, by the rules that land a lone repository's worktree. They keep a package with uncommitted changes, one with a detached head, and a dropped order's package whose changes its base lacks. Then they delete the Brazil worktree, run the teardown of each package in `verify-<KEY>`, and delete it too. A teardown file lives in the package directory, `<wt>/src/<Pkg>/.claude-artifacts/teardown.sh`, never at the Brazil worktree's root, where nothing runs it. A `package-lock.json` the Gate rewrote and nobody restored keeps the worktree.

## Subagents

`isolation: "worktree"` fails at `<ws>`, which is not a git repository. Dispatch without it. Brief each agent with the one package directory it may change, and tell it never to touch `<ws>/src`. Two agents that run at once never write the same package directory.

## Not supported

- `kitchen.zsh stage`, so `catering` and its staged review. It refuses this line.
- `EnterWorktree`, until it is shown to accept a package worktree and still leave the others writable.
- A ticket whose packages need two version sets in one order. It becomes a multi-phase plan, as intake step 8 says.
- `/kitchen taste` on a branch outside an order, since `kitchen.zsh each` needs an order's packages and bases.
