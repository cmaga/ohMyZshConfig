# Correct

Find the mistakes agents keep repeating in a project and make each one impossible: architecture first, then types, then a lint whose error names the fix, then a test, and docs last. Prove each check fails on a real past mistake.

The user keeps correcting agents in this project for the same mistakes. Change the project so the next agent can't make them.

Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles. Design the project so a change that looks right from one file is right for the whole project.

## Find the mistake classes

First, read recent commits, reverts, review comments, agent instruction files (`CLAUDE.md`, `.claude/rules/`, and the project rules in `.claude/kitchen/house.md`), the catch classes `kitchen.zsh classes` prints for the project, and comments that explain workarounds. Group the mistakes into classes. A class counts once it has happened twice.

## Fix each class at the highest level that works

1. **Eliminate it with architecture.** Give each piece of state one owner and each task one supported way. Hide internals so the wrong import fails. Replace hand-synced lists with one source of truth. Delete old ways and dead code an agent would copy.
2. **Enforce it with types so the bad state can't be written.** If bad code still compiles, add a lint or CI check whose error names the file, type, or function to use instead. If the pattern is already common, fail only when a change adds more.
3. **Test the behavior.** Fix or delete any test that still passes when the behavior it checks breaks, or that fails when only the internals change.
4. **Write docs or agent rules last, only for judgment calls.** Nothing fails when an agent skips them.

## Fix and prove

Then fix the most frequent classes now, one commit each. Prove each new check fails on a real past mistake. Run the same command locally and in CI. Exceptions go on the offending line with a reason, an expiry date, and the user's approval.

## Keep the rule table

Last, keep the `## Rules` table in the project rules (`.claude/kitchen/house.md`), which pairs each rule with what enforces it and the rung it sits on. Add a row for each class you fixed, and drop a rule once its mistake can't happen.

**Reply:** each class with its evidence, the level you picked, and why a higher level didn't work.
