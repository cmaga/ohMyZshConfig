# Recipe: catering

A new system, a new design, or a large refactor whose target design is unsettled. With the user, you agree the context and goals, investigate, settle a direction, and write three documents: the plan, for them or a team to review; the spec, a functional spec for agents; and the implementation plan, which puts every call an agent would make to the user now. The work then ships in deployments: one order and one PR each, its skeleton built with the user and its bodies in the project's highest unlocked mode. Once every deployment merged, the user runs `/kitchen cook <KEY>` once more, and the planning documents retire into documentation.

Every stage of this order runs with the user, so it has no mode (its `mode` is only the default, and no rule for manual orders applies to it), and the scheduler never starts it. Every row works in the order's worktree, `.claude/worktrees/<KEY>`, entered per [cook](../cook.md) steps 5 and 6, which pick up where an earlier session stopped. The documents live there, untracked, in the order's `docs` directory, and its deployments read them by that path, so the worktree stays until wrap-up.

Find where it stands from the order's `stage` and its PR (the order's `pr`, or one the provider lists for the branch), whose state you read through the `git-provider` skill:

| `stage` | PR | Do |
|---|---|---|
| empty or `plan` | | Move the ticket per [cook](../cook.md) step 9, then plan per [plan](catering/plan.md). |
| `spec` | | Write the spec per [spec](catering/spec.md). |
| `implementation` | | Write the implementation plan and file the deployments per [implementation](catering/implementation.md). |
| `building` | none | When every order in its `after` is done (`kitchen.zsh order get <DEPLOYMENT-KEY>` for each), wrap up per [wrap-up](catering/wrap-up.md). Otherwise say which deployment waits on what, and stop. |
| `building` | open | The docs PR: with the user here, fix what their comments on it ask and, after a `FAIL` verdict, each finding in its `verdict_notes` per [follow a PR](follow-a-pr.md) step 6. Push, run `kitchen.zsh order pr <KEY> <url>`, then `kitchen.zsh order verify <KEY>` when you fixed a finding, and stop. |
| `building` | merged | `kitchen.zsh order close <KEY>`, and end. |
| any | closed without merging | Ask the user whether to work it again. If so, run `kitchen.zsh order set <KEY> pr=` and go on as for no PR. |

A deployment order carries `catering`, the epic's key, and follows [deployment](catering/deployment.md).

## Talking to the user

Every stage moves one point at a time: track the points with `TaskCreate` (the list is the agenda and the resumption state), discuss one until the user is satisfied, then stop until they say `next`. Discussing and writing are separate acts: a point goes into a document only on their word. When a question needs real data, dispatch it to a background agent and keep discussing.

When a stage shows the user a document, give them its path; they read and edit it directly, and their text wins, so read it again before the next point. Make each change they ask for, say what changed, and stop. A stage moves on only on their go.
