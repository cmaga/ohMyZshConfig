# Recipe: catering

A new system, a new design, or a large refactor whose target design is unsettled. The user writes a spec with you and plans its milestones with you; those two are serving, so the scheduler never starts them, and the user runs `/kitchen cook <KEY>` in a session. Each milestone then becomes an ordinary order the scheduler cooks headless on the branch `spec/<EPIC>`, and this order comes back once more, headless, to deliver that branch as one PR. Once the epic is filed, every `kitchen.zsh` command takes the epic's key in place of this order's.

Every row works in the order's worktree, entered per [cook](../cook.md) steps 5 and 6, which pick up where an earlier session stopped. Find where it stands from the order's `spec` and `stage` fields and its PR (the order's `pr`, or one the provider lists for the branch), whose state you read through the `git-provider` skill:

| `spec` | `stage` | PR | Do |
|---|---|---|---|
| empty | | none | Move the ticket per [cook](../cook.md) step 9, and write the spec per [spec](catering/spec.md). |
| empty | | open | Fold in the user's comments on the PR per [spec](catering/spec.md) step 6, push, run `kitchen.zsh order pr <KEY> <url>`, and stop. |
| empty | | merged | Run [spec](catering/spec.md) wrap-up step 4, which goes on into the plan. |
| set | empty | | Plan it per [plan](catering/plan.md). |
| set | `close` | none | Deliver it per [close](catering/close.md). |
| set | `close` | open | With the user here, fix what their comments on it ask and, after a `FAIL` verdict, each finding in its `verdict_notes` per [follow a PR](follow-a-pr.md) step 6. Push, run `kitchen.zsh order pr <EPIC> <url>`, then `kitchen.zsh order verify <EPIC>` when you fixed a finding, and stop. |
| set | `close` | merged | `kitchen.zsh order close <KEY>`, and end. |
| either | either | closed without merging | Ask the user whether to work it again. If so, run `kitchen.zsh order set <KEY> pr=` and go on as for no PR. |

## The milestone orders

A milestone order is a `feature`, `refactor`, `bug-fix`, or `perf` order like any other, cooked by its own recipe. It carries `spec` (the spec's path), `parts` (the spec's part ids it touches), and `base=spec/<EPIC>`, so its worktree starts from that branch and its PR merges into it. Its `after` lists the milestones it builds on, and the scheduler starts it only once each of those is done.

- **A dropped milestone holds the rest.** A milestone at `86` blocks every order whose `after` names it, the close included, and `kitchen.zsh status` shows them `BLOCKED`. Bring it back with `kitchen.zsh signoff <KEY> @<file>`, or take it out of each waiting order's `after` with `kitchen.zsh order set <LATER> after=@<file>`.
- **The spec is its guidance.** Read the sections for its `parts` before its recipe's first step, and hold the code to them.
- **A call that changes the spec is yours to make**, per [SKILL.md](../../../SKILL.md#autonomy), unless it overturns what the user decided. Commit the spec change in this order's PR, its commit body saying why. In the same session, update everything that relied on the old text: each later milestone it touches (`kitchen.zsh order set <LATER> done_when=@<file> station=@<file>`), their tickets through the `ticket-provider` skill, and the plan. Record the call with `kitchen.zsh decide`.
