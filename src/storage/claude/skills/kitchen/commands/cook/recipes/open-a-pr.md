# Open a PR

The end of every recipe that ships a change: hold the quality gate, shape the commits, and open a PR a reviewer can read in a minute.

Contents: Steps, Commits, Titles, The PR body, Size and stacks.

## Steps

1. **Hold the quality gate**: follow the [taste](../../taste/taste.md) command on this branch with the order's key and done-when. Nothing goes out until it clears.
2. **Triage what is left** per the [left for you](../stations/left-for-you.md) station.
3. **Record the gate.** When a vault rule under `.claude/rules/vault/` loaded for a file you changed, first dispatch `vault-scribe-agent` with what changed and why; nothing else writes vault notes. Then `kitchen.zsh order gated <KEY>` records the change the gate passed, so a later change to it is caught.
4. **Run the full suite once.** First fold the fixups in and catch up with the base in one rebase: `git fetch origin <base>`, then `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash origin/<base>`, resolving any conflict so both sides' intent survives. Then run the `Gate` command from the project rules (`.claude/kitchen/house.md`). Red: fix with fixups, re-run only the failures each fix could change, then every failure once, then the full suite; a test that fails twice at the same step after a fix is a finding to trace, not one to rerun, and rebase again while fixups are left. Green: `git push --force-with-lease -u origin HEAD`.
5. **Open the PR.** First settle the review flag: when step 2 left any item and the order is not already flagged, run `kitchen.zsh order set <KEY> review=true "review_why=left for you: <n> items"`. Then open the PR through the `git-provider` skill, ready and never as a draft, targeting `<base>`, with a title and body per the sections below written through the [technical writing](../stations/technical-writing.md) and [unslop](../stations/unslop.md) stations. Record it with `kitchen.zsh order set <KEY> pr=<url>` and move the ticket with `transitions.review`.
6. Run the [merge](merge.md) recipe. A PR flagged for the user's review still gets its verdict first: `sample` prints `verify` before `review`, and the PR goes to the user only when `sample` prints `review`.

Opening a PR does not start a [follow a PR](follow-a-pr.md) pass. The scheduler wakes a session when the PR changes.

## Commits

Commit liberally while working, then shape the history in step 4 into small, ordered commits, each landable and ordered to tell the story. Amend when a fix belongs in the commit just made; make a new commit when it is separable; on a commit further back, `git commit --fixup=<sha>`. A relocation is one commit per move. Commit bodies don't restate the subject. Use the project's commit format; with none, Conventional Commits.

## Titles

`type(scope): subject`, no trailing period, unless the project's format says otherwise. Type such as `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, or `perf`; scope is the area; the subject is short, imperative, and names a real symbol when one carries the change. Start it with the ticket key when the project's titles do.

## The PR body

A one-minute briefing for a reviewer who has the diff, not a lab notebook. It says why the change exists, what it leaves out, what it could break, and how you proved it works. Short, simple sentences with few identifiers. Use `##` headings in this order and drop a section with nothing to say:

- `## Why`: the user's goal (the order's intent) and the approach, in one to three sentences. Who the change is for and what changes for them. No SHAs or rebase history.
- `## What changed`: one to three bullets. Name a real symbol or path only when it carries the change; name both sides of a rename.
- `## Scope`: always. One to three items on what it covers and what it deliberately leaves out.
- `## Tradeoffs`: only rejected alternatives a reviewer would otherwise ask about.
- `## Blast radius`: each consumer of what changed and the run that confirmed it survives, from the [blast radius](../stations/blast-radius.md) station. One or two sentences when nothing outside the diff reads it.
- `## Verification`: each done-when line with the run that proved it and its outcome, and each contract test with the line it pins. A contract corrected after the code says what changed and why. For perf, one primary number with its unit, before and after, with the rest in a linked artifact.
- `## Decided alone`: every decision from the order's `decisions`, with its evidence.
- `## Attention`: when the work kept a decision log, its review per the [show me your work](../stations/show-me-your-work.md) station.
- `## Left for you`: the items from step 2, one question each, or the line "Nothing is left for you."

These last three sections address the user and appear only when the order waits for the user's review (`review=true`). Otherwise the body ends at `## Verification`; the calls stay in the order book, where `kitchen.zsh status` lists them as decided alone in the user's catch-up.

After the sections, attach screenshots or a video when they prove a claim. Full SHAs, lane recitals, and file-by-file checklists go in a linked artifact, not the body.

## Size and stacks

Prefer several narrow PRs to one large one; an order whose change splits cleanly says so in **Left for you** or, at intake, becomes a [multi-phase plan](multi-phase-plan.md). A stack is a chain of base branches: the root PR targets the base, and each child branch rebases onto its parent's exact tip and targets the parent's branch (`gh pr create --base <parent-branch>`). Branch from the base only for independent work.

**Reply:** the PR link as a full URL, what it changes for whom, and anything waiting on the user.
