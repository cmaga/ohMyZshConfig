# Verify: the verdict on a PR

You did not write this change. Run it the way a user would, base against head, and give it `PASS`, `PASS+NOTES`, or `FAIL`. Only a verdict from a session or agent that did not write the code counts: an author checks what it meant to build, and you check what it built. You change no code and push nothing.

The scheduler starts you (`/kitchen taste verify <KEY>`, phase `verify`) when a PR waits on its verdict; with the user here, cook dispatches you as a fresh agent. Never run `kitchen.zsh order claim`: the order stays with the scheduler.

1. **Read the order**: `kitchen.zsh order get <KEY>` for the intent, the done-when, the PR, and any earlier verdict's `verdict_notes`. Read the PR body and diff through the `git-provider` skill. Every claim in them is something to check, not evidence.
2. **Check out the PR head on your own.** As a scheduler session, `EnterWorktree` with `name: verify-<KEY>`; as a dispatched agent you already have a worktree. Then `git fetch origin <base> <branch>` and `git checkout --detach origin/<branch>`. The base branch is what `kitchen.zsh order base <KEY>` prints, with `-` for the key outside an order.
3. **Re-run the gates**: `bash ~/.claude/skills/kitchen/dependencies/scripts/contract-check.sh origin/<base> --run`, which confirms nobody but the contract author touched the tests and each one ran and passed, then every `check:` command and the `Gate` in the project rules (`.claude/kitchen/house.md`). After each step, run `kitchen.zsh order set <KEY> "step=verify <n>"` so the scheduler sees progress.
4. **Drive the change live** through the project's verify skill (`.claude/skills/verify*`), else the `run` skill: each done-when line, then the flow the intent names, end to end, on the head and on the base. Drive at least one behavior with inputs you pick yourself, never a contract test's: the coder saw those, and code shaped to them passes them. A line that passes on both cannot see the change; say so. A change to a shared interface drives each consumer's flow too. Keep the evidence (screenshots, outputs, logs) where the verify skill says it survives cleanup.
5. **Audit the diff against the intent**, distrusting the PR body: what the intent needs that the diff lacks, and what the diff does that the intent does not need. Each suspicion becomes a run, per the [blast radius](../cook/stations/blast-radius.md) station's proof ladder. Leave mutation testing out: taste's mutation sweep already ran the contract against every changed line, and the order's `decisions` record each mutant it called equivalent.
6. **Judge.** Block only on a problem you can show with a run at the head: a bug a user would hit, a failed gate, or a doc line the PR made wrong. A problem the base already has blocks only when the PR copies it or newly reaches it. Everything else is a note.
   - `FAIL`: at least one blocking problem.
   - `PASS+NOTES`: nothing blocks, and something is worth a follow-up.
   - `PASS`: nothing blocks and nothing to add.
7. **Answer the review criteria.** Read `## Review when` in the project rules (`kitchen.zsh rules`) and answer each question for this change, from the diff and your runs. Keep each one that holds as a reason, `<question>: <why, with file:line>`. Answer for the change itself, never for the code around it.
8. **Record it.** Write the notes to a file: for each finding the command, the output it printed, and what the intent requires; for a pass, what you ran and saw. From the checkout of the head you verified, run `kitchen.zsh order verdict <KEY> <WORD> @<file>`, followed by each step 7 reason as its own quoted argument. Post nothing on the PR.
9. **Clean up** what you started, keeping the evidence, then `ExitWorktree` with `action: "remove"`.

**Reply:** the verdict, the review criteria that hold, what you ran on head and base, each finding with its command and output, and where the evidence is.
