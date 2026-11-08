# Contract

Write the tests before the code is handed off, as a contract between the session that decides what the code must do and the agent that writes it. A coder talks itself out of anything it can argue with; it cannot argue with a test it may not edit. Every recipe that ships code runs this before its code delegate starts. Prototype and investigation skip it.

## Who writes it

A `worker-agent` on the contract role ([SKILL.md](../../../SKILL.md#subagents)), never the agent that will write the code. Brief it with this file's path, the intent, the done-when, the scope, and the recipe. Existing tests the change makes wrong are its to update, in the contract commit.

## What the tests answer to

A test is only as right as what it was checked against, and a test seen only failing has been checked against nothing. Each recipe has its own oracle:

- **Bug fix**: the report. One test that reproduces the bug through the real code path and fails on the base branch with the reported symptom.
- **Refactor**: the current code. Pins that pass on the base branch and must still pass after.
- **Feature**: there is none, so the tests are the spec. Write them from the done-when and the edge cases that change what a user sees, through the interface users touch, never against internals. When they need something to call, the author first commits the scaffold: the signatures, types, and modules the code will fill, each body raising the language's not-implemented error. Then you, not the author, read each test against the intent before the coder starts, and send back any that pins the wrong behavior.
- **Perf and hillclimb**: the frozen harness and its baseline.

## The fewest tests that hold

Count tests against the contract, not the code, per the [test behavior, not implementation](../../../dependencies/principles/test-behavior-not-implementation.md) principle.

- Each test's name says which done-when line or edge case it pins. A test that pins none is not written.
- One test per behavior. An edge case gets its own test only when it changes what a user sees.
- The tests supply their whole world: every fixture, recording, seed, and piece of state they read exists when the contract lands, so each fails only on the behavior it pins. Ask who owns any you cannot write.
- With no cheap test path (broad harness setup, brittle mocks, production-only state), the contract is the closest runnable check, a script or a drive through the verify skill, and the author says why. No test beats a bad test.

## Lock it

Commit the contract, scaffold aside, as `git commit -m "test(contract): <what it pins>"` with one `--trailer "<key>: <value>"` per trailer line, since git reads trailers only from a message's last paragraph. The message reads:

    test(contract): <what it pins>

    Contract-Files: <test path> <test path>
    Contract-Run: <command that runs these tests, printing one line per test with its result>
    Contract-Test: <a test's name exactly as that command prints it>
    Contract-Test: <the next>

- Pick a run command whose output names each test: `pytest -v`, `vitest run --reporter=verbose`, `jest --verbose`, `go test -v`, `cargo test`.
- Every contract commit restates the whole contract. A later one (the next milestone's, a correction) lists every file, run, and test still in force, and a correction's body says why.
- Leave `Contract-Run` and `Contract-Test` off only for tests too slow to run at every check, such as an end-to-end proof. Their files stay locked.

Only a contract commit may touch a contract file. `bash ~/.claude/skills/kitchen/dependencies/scripts/contract-check.sh origin/<base> --run` checks that, and confirms each named test ran and passed. The [taste](../../taste/taste.md) and [verify](../../taste/verify.md) commands run it, and taste also runs the mutation sweep once the code exists, so every changed line has a test that fails when it breaks. Pin every survivor the sweep lists in one correction, not one at a time.

## The coder's side

- The code delegate's brief carries the contract files and the `Contract-Run` command. It does not carry the done-when or how the verify session will drive the app: those stay the check the coder never saw.
- The coder runs the contract as often as it likes, keeps no tests of its own, and challenges a test it believes wrong in its report instead of editing it.
- A challenge you accept goes back to the contract author as a correction. The coder never makes a contract commit.

**Report:** each contract test with the line it pins and how it failed before the code (the reported symptom for a bug, the not-implemented error for a feature), and each place no test was cheap with what stands in for it.
