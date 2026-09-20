# The done-when check

Read the component's acceptance list against the merged tree and confirm each line is true. Nothing else in this workflow reads the contract: a green suite proves the tests pass, a passed review proves the code is correct, and a stub satisfies both. `grep -rn NotImplementedError <dir>/` once would have caught a component whose ten central call sites all raised.

## What to read

Unless the spec wrote an explicit acceptance list, the component's acceptance is its **Tests**, its **Owns** line, and every sentence in its body stating what becomes true. Where the spec carries an explicit list, that list wins and the Tests are the check for it.

## The check that did not follow

**A component that creates a second instance of something the build already gates owes that gate its extension.** Ask it of every component that adds a database, a migration history, a package root, a lint scope, an allowlist, or a service: which existing check counted one of these, and does it now count both. It is part of this component's acceptance whether or not its section says so.

## Who runs it

**The parent, never the component's own agent** — that agent is the party that wants to be done.

## How

For each line:

1. **Name the sentence you are checking.** The same words mean different things in the boundary paragraph, the description, and the acceptance list. Quote it.
2. **Write a check that could fail.** One command with visible output beats a judgement.
3. **Run it against the base branch too.** A check that returns the same answer before and after cannot detect the change it claims to verify.
4. **Never suppress stderr on a verification probe.** `2>/dev/null` converts an error into an empty result that reads as a pass.
5. **Census, do not count.** A spec's enumeration can be aspirational; enumerate the real thing and report the disagreement.

## What a failure means

A line that does not hold goes back to the component's own agent with the sentence and the failing check. If the component reports it met and your check says otherwise, read its reasoning before ruling — the disagreement is often about which sentence was tested. Where a component claims partial delivery, make it enumerate what is **not** built.
