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

1. **The done-when**, per [done-when](done-when.md): each line run on the branch and on the base branch. A line that passes on both cannot see the change; fix the check before the code. Behavior lines are driven through the project's verify skill (`.claude/skills/verify-*`), else the `run` skill. When the verify skill fails at a step the app actually handles correctly, the verify skill drifted: fix its map on this branch per [calibrate](calibrate.md), never the app. Drive the change in the real app even when no done-when line names a behavior, unless it has no runtime surface; say which. A change to a shared interface drives each consumer flow too. Drive the app through Playwright MCP, and use the built-in Chrome for anything else. When a drive needs a browser and the project has no Playwright MCP config, or a drive hits a locked browser profile, run the `playwright-mcp-setup` skill first; headless, run `kitchen.zsh order set <KEY> status=86 "reason=parked: driving the app needs the playwright-mcp-setup skill run in this project"` and end.
2. **Checks.**
   - **The contract held**: `bash ~/.claude/skills/kitchen/dependencies/scripts/contract-check.sh origin/<base> --run`. A broken lock means a coder edited the contract: take that edit out of the branch, never bless it with a new contract commit. A failed or missing test goes back to the code. `no contract commit` on code a recipe shipped means its [contract](../cook/stations/contract.md) step was skipped: run it now. Run on its own, report it.
   - **Each contract test can fail**: with the tree clean, break the behavior a test names (a wrong value, a skipped effect, the effect done twice), run that test, see it fail, and `git restore` the file. A test that still passes proves nothing or never ran: find which, and have the contract author fix or cut it.
   - Run every `check:` command in the project rules, and the `Gate` when taste runs on its own; under an order, the Gate runs once at [open a PR](../cook/recipes/open-a-pr.md) step 4. Fix until green.
3. **Tasters**, in parallel: one `taster-agent` per name under the project rules' `## Tasters`, else the defaults below. Give each one inline its name and definition (a default's from below, or the text after its name in the project rules), the rule rows whose enforcer is `taster: <name>`, the project rules' `Reach`, the diff range `origin/<base>..HEAD`, the change's intent, and its known classes from `kitchen.zsh classes <name>` (none when the project is not registered). The gaming taster also gets the contract test paths and step 2's contract check output.
4. **Comments**: the [no-comments](../cook/stations/no-comments.md) station on the same diff.
5. **Bugs**: the [bug review](#bug-review) below.
6. **Fix and log every taster finding.** Fix what is inside reach. Then log each finding, inside reach or not, its one-line note written to a file first:

       kitchen.zsh catch <KEY or -> <taster> <class> @<file>

   - `promote`, once per class however many catches print it: file a ticket via the `jira` skill, "Enforce <class>", listing the catches `catch` printed. Then `kitchen.zsh order new <NEW-KEY>`, which intake serves like any ticket, and `kitchen.zsh promoted <class> <NEW-KEY>`.
   - `climb <ticket>`: the enforcement from `<ticket>` did not take. Promote the same way, with the intent "Enforce <class> at least one rung above <ticket>'s".
   - `kitchen.zsh catch` fails when the project is not registered: then skip logging and list the findings in your report.
7. **Re-run the checks** after the last fix: the `check:` commands, and the `Gate` when taste runs on its own.
8. **Report**: each done-when line with its evidence, what each taster and the no-comments pass found and what you fixed, the bug review's rounds and verified findings, and what is left for the user. Run from an order, carry on at the next step of [open a PR](../cook/recipes/open-a-pr.md); run on its own, give the report to the user.

## Default tasters

- **tidy**: what the next reader of the code within reach would trip on. Unclear names, needless indirection, dead code, duplicated logic.
- **consistency**: the change does something the codebase already has a way to do, and does it differently or builds it again. The existing way wins.
- **test-honesty**: a test the change adds outside the contract, a test that would still pass if the behavior it names broke, a test that fails when only internals change, or a mock of the thing under test.
- **minimal**: code the done-when does not need. Speculative options and parameters, an abstraction with one caller, defensive handling of a state the types or callers rule out, files touched that the change did not require.
- **gaming**: code that passes the contract without doing what it promises. A branch on a test's exact inputs or on running under test, a test's expected value hardcoded in source, a change to the test runner's config, setup, or skip markers that changes what runs, and a contract commit made after the code that weakens a test.

## Bug review

Run the [interrogate](../cook/stations/interrogate.md) station on the diff (or the range a caller names), with the change's intent and done-when. Its adversaries prove each finding with a run; it reports only verified findings and never fixes.

**Fixing a verified finding.** Read every function on the path end to end before editing; a finding names a symptom and a line, and the defect is often neither. Fix it yourself at its root, its repro joining the contract per the [contract](../cook/stations/contract.md) station where a test is cheap, and commit the fix as a fixup of the commit that introduced the bug. A recurring finding lists examples only; sweep the diff for the rest. Sweep for the claim, not the symbol: everywhere that quotes the old behavior is stale, and a grep for the symbol will not find it; check the wiring module, the entry point, and the README.

**Rounds.** Run interrogate again on your fixes. Stop when a round has no verified findings. After three rounds with verified findings left, say so in the report and carry on; what is still open goes through [left for you](../cook/stations/left-for-you.md#triage).

A suspected bug no run could reproduce is not confirmed: record it with `kitchen.zsh decide <KEY> "unproven: <scenario>: <why no run reproduced it>" "<the command you ran>"` (in your report when the key is `-`), and change no code for it.
