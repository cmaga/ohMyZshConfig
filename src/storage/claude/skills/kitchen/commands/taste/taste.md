# Taste: hold the quality gate

[Open a PR](../cook/recipes/open-a-pr.md) runs this as the quality gate on every order; `/kitchen taste` runs it on any branch.

The quality of the code is capped by what gets checked, and an agent told to check one thing checks that thing well and misses what sits beside it. So the done-when is run, every dimension the project rules name gets its own narrow reviewer, comments get their own hater, and adversaries try to break the change. Only what a run proves counts as a bug.

## Inputs

- **The branch**: the current one unless named; check a named one out here first, and when git refuses (uncommitted changes, or another worktree has it), say why and stop. The base branch is what `kitchen.zsh order base <KEY>` prints, with `-` for the key outside an order.
- **The order key**, when cook runs this; otherwise `-`. Run on its own, commit each fix on the branch and leave pushing to the user.
- **The done-when**: the order's, when there is one. Otherwise derive it from the PR description and commit messages: each claim of what now works becomes a check.
- **The project rules**: `.claude/kitchen/house.md` in the project. When it is missing, use the default reviewers below, Reach `touched lines`, and the project's own lint, type, and test commands, and say so.

## Steps

Under an order, after each step run `kitchen.zsh order set <KEY> "step=taste <n>"` so the scheduler sees progress.

1. **The done-when**, per [done-when](done-when.md): each line run on the branch and on the base branch. A line that passes on both cannot see the change; fix the check before the code. Behavior lines are driven through the project's verify skill (`.claude/skills/verify*`), else the `run` skill. When the verify skill fails at a step the app actually handles correctly, the verify skill drifted: fix its map on this branch per [calibrate](calibrate.md), never the app. Drive the change in the real app even when no done-when line names a behavior, unless it has no runtime surface; say which. A change to a shared interface drives each consumer flow too. Drive the app through Playwright MCP, and use the built-in Chrome for anything else. When a drive needs a browser and the project has no Playwright MCP config, or a drive hits a locked browser profile, run the `playwright-mcp-setup` skill first; headless, run `kitchen.zsh order set <KEY> status=86 "reason=parked: driving the app needs the playwright-mcp-setup skill run in this project"` and end.
2. **Checks.**
   - **The contract held**: `bash ~/.claude/skills/kitchen/dependencies/scripts/contract-check.sh origin/<base> --run`. A broken lock means a coder edited the contract: take that edit out of the branch, never bless it with a new contract commit. A failed or missing test goes back to the code. `no contract commit` on code a recipe shipped means its [contract](../cook/stations/contract.md) step was skipped: run it now. Run on its own, report it.
   - **Every changed line has a test that fails when it breaks**: with the tree clean, run `python3 ~/.claude/skills/kitchen/dependencies/scripts/mutation-sweep.py origin/<base>`, which mutates each changed source line and runs the contract against each mutant. Brief the contract author once with every survivor it lists: pin each, or name it equivalent with the reason no test can tell it apart. Record each equivalent with `kitchen.zsh decide <KEY> "equivalent mutant: <path:line> <operator>: <why>" "<the sweep's output file>"`. Rerun the sweep on the correction until every survivor is pinned or recorded.
   - Run every `check:` command in the project rules, and the `Gate` when taste runs on its own; under an order, the Gate runs once at [open a PR](../cook/recipes/open-a-pr.md) step 4. Fix until green.
3. **Tasters**, in parallel: one `taster-agent` per name under the project rules' `## Tasters`, else the defaults below. Give each one inline its name and definition (a default's from below, or the text after its name in the project rules), the rule rows whose enforcer is `taster: <name>`, the project rules' `Reach`, the diff range `origin/<base>..HEAD`, the change's intent, and its known classes from `kitchen.zsh classes <name>` (none when the project is not registered). The gaming taster also gets the contract test paths and step 2's contract check output.
4. **Comments**: the [no-comments](../cook/stations/no-comments.md) station on the same diff.
5. **Bugs**: the [bug review](#bug-review) below.
6. **Fix and log every taster finding.** Fix what is inside reach. Then log each finding, inside reach or not, its one-line note written to a file first:

       kitchen.zsh catch <KEY or -> <taster> <class> @<file>

   - `promote`, once per class however many catches print it: search the base branch for the pattern the catches describe.
     - **Found in more places than this branch can fix without doubling its diff:** the codebase taught the slip, so it gets a cleanup, not a check. Search the tracker per [left for you](../cook/stations/left-for-you.md#discovered-issues) for an open ticket cleaning it up; with none, file one through the `ticket-provider` skill without asking, "Clean up <class>": how many instances and where, the command that finds them, and what to write instead per the language's, stack's, and industry's best practice, with sources. Open no order for it. Then `kitchen.zsh promoted <class> <its key>`.
     - **Found in a few places:** fix them on this branch, then, run from an order, `kitchen.zsh promoted <class> <KEY>`.
     - **Not found:** a real slip, and only the user decides on a check. Search the tracker the same way for an open "Enforce <class>" ticket; one found answers it: `kitchen.zsh promoted <class> <its key>`. Otherwise file nothing. With the user here, ask once at the hand-back about every due class together, each with its catches: one "Enforce" ticket for them all, or leave them. On their go, file it listing each class's catches, run `kitchen.zsh order new <NEW-KEY>`, and `kitchen.zsh promoted <class> <NEW-KEY>` for each class; for each class they leave, `kitchen.zsh promoted <class> -`, which drops it from the catch-up until its next catch makes it due again. Headless, leave it: the user's catch-up lists every due class.
   - `climb <ticket>`: the slip came back after `<ticket>` landed. Handle it as a real slip; a check it asks for starts at least one rung above any `<ticket>` built.
   - `kitchen.zsh catch` fails when the project is not registered: then skip logging and list the findings in your report.
7. **Re-run the checks** after the last fix: the `check:` commands, and the `Gate` when taste runs on its own.
8. **Report**: each done-when line with its evidence, the sweep's survivors and how each was settled, what each taster and the no-comments pass found and what you fixed, the bug review's verified findings, and what is left for the user. Run from an order, carry on at the next step of [open a PR](../cook/recipes/open-a-pr.md); run on its own, give the report to the user.

## Default tasters

- **tidy**: what the next reader of the code within reach would trip on. Unclear names, needless indirection, dead code, duplicated logic.
- **consistency**: the change does something the codebase already has a way to do, and does it differently or builds it again. The existing way wins.
- **test-honesty**: a test the change adds outside the contract, a test that would still pass if the behavior it names broke, a test that fails when only internals change, or a mock of the thing under test.
- **minimal**: code the done-when does not need. Speculative options and parameters, an abstraction with one caller, defensive handling of a state the types or callers rule out, files touched that the change did not require.
- **gaming**: code that passes the contract without doing what it promises. A branch on a test's exact inputs or on running under test, a test's expected value hardcoded in source, a change to the test runner's config, setup, or skip markers that changes what runs, and a contract commit made after the code that weakens a test.

## Bug review

Run the [interrogate](../cook/stations/interrogate.md) station on the diff (or the range a caller names), with the change's intent and done-when. Its adversaries prove each finding with a run; it reports only verified findings and never fixes. Tell them the mutation sweep (step 2) already ran, so a mutated line the tests miss is not a finding; they hunt bugs a caller would hit and tests that pass for a reason other than their line.

**Fixing a verified finding.** Read every function on the path end to end before editing; a finding names a symptom and a line, and the defect is often neither. Fix it yourself at its root, its repro joining the contract per the [contract](../cook/stations/contract.md) station where a test is cheap, and commit the fix as a fixup of the commit that introduced the bug. A recurring finding lists examples only; sweep the diff for the rest. Sweep for the claim, not the symbol: everywhere that quotes the old behavior is stale, and a grep for the symbol will not find it; check the wiring module, the entry point, and the README.

**One round.** Run interrogate once; a second round on the fixes mostly adds false positives (arXiv 2603.16244). Prove each fix with its repro failing before the fix and passing after, rerun the mutation sweep on the fixes, and name each fix in the report as checked by its repro and the sweep. What you leave unfixed goes through [left for you](../cook/stations/left-for-you.md#triage).

A suspected bug no run could reproduce is not confirmed: record it with `kitchen.zsh decide <KEY> "unproven: <scenario>: <why no run reproduced it>" "<the command you ran>"` (in your report when the key is `-`), and change no code for it.
