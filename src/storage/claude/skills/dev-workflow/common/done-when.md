# The done-when check

Read the component's acceptance list against the merged tree, and confirm each line is true.

Nothing else in this workflow reads the contract. A green suite proves the tests pass, and the tests were written by the same agent that wrote the code they cover — a skeleton with tests written for the skeleton is perfectly green. The review gate reads the diff and asks whether the code is correct, which a well-formed stub is. The merge condition is a green suite and a passed review. So the acceptance list — the thing the user actually approved — is read at dispatch and never again.

What that costs, measured once: a component merged on three days of green builds, both pipelines passing, 7,176 tests and a thorough exit report, whose ten central call sites all raised `NotImplementedError`. Its acceptance line said every gate was at the door. `grep -rn NotImplementedError <dir>/` would have caught it in a second.

## What to read

The [spec template](../templates/spec-template.mockup.html) defines no acceptance section, so unless the spec wrote one of its own, the component's acceptance is three things read together: its **Tests** — the scenarios it closes with, which the spec's adversarial pass filled and which are the closest thing to a signed contract it has — its **Owns** line, and every sentence in its body stating what becomes true. Where the spec does carry an explicit list, that list wins and the Tests are the check for it.

## Who runs it

**The parent, never the component's own agent.** That agent is the party that wants to be done, and its exit report is its own account of itself — honest in its own terms and silent about the terms it did not choose.

## How

For each line in the component's acceptance list:

1. **Name the sentence you are checking.** The same words appear in a component's boundary paragraph, in its description of what changes, and in its acceptance list, and they do not mean the same thing in all three. One component reported its own line failed because it held itself to the stricter boundary reading; another passed itself against the looser one. Quote the sentence in your check, so the next reader can see which one you tested.

2. **Write a check that could fail.** Prefer one command with visible output over a judgement. `grep -c` beats "I read the file and it looked right."

3. **Run it against the base branch too.** This is the whole difference between a check and a rubber stamp. A check that returns the same answer before and after cannot detect the change it claims to verify, and running both is how it announces that about itself. One acceptance check in this workflow reported a list emptied from 28 entries to zero; the ref had been silently mangled, the command had failed, and the base-branch run returned 28 — a number that could not be both before and after.

4. **Never suppress stderr on a verification probe.** `2>/dev/null` is fine when you are probing for existence and poison when the output *is* the evidence: it converts an error into a finding, and an empty result is the most seductive form of absence because it looks like a clean pass.

5. **Census, do not count.** A spec's enumeration can be aspirational. One naming eight gates had roughly twenty real refusal sites, and three of the eight enforced nothing at all. A check that reads the same sentence the component read inherits the same wrong number — enumerate the real thing and report the disagreement.

## What a failure means

A line that does not hold is not a bug to patch here. Send it back to the component's own agent with the sentence and the failing check, the way any other return is handled. If the component reports the line as met and your check says otherwise, read its reasoning before ruling — the disagreement is as likely to be about which sentence was tested as about the code.

Where a component claims partial delivery, make it enumerate what is **not** built, specifically. A label carries whatever the last component meant by it.
