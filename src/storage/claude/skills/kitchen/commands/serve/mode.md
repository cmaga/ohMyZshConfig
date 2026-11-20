# Mode: recommend how an order is worked

Intake recommends a mode beside the approach, and the user approves or changes it. The mode says who writes the code:

- `manual`: the user writes it, starting from tests the contract station wrote first, which they may change. The session only looks things up for them.
- `guided`: the line writes it, with the user in the session to ask.
- `auto`: the line writes it headless, started by the scheduler. It never waits on the user.

## Inputs

- **The modes this project has unlocked**: `kitchen.zsh modes`. Offer only those; `kitchen.zsh order set` refuses a mode the project has not unlocked and says which threshold is unmet.
- **The project rules** (`kitchen.zsh rules`): `## Sorting`, `## Critical`, and `## Always review`.
- **The order's `station`**: the files intake expects the order to touch.

## The rules

Take the first rule that matches among the unlocked modes. `manual` applies only to recipes that ship code (feature, bug-fix, refactor, perf, hillclimb); an investigation, prototype, eval, or multi-phase-plan is `guided` or `auto`. A `catering` order takes no mode: it runs with the user, and each deployment it files takes the project's highest unlocked mode.

1. **A `## Sorting` rule** that names a mode for this ticket. It is the user's earlier call.
2. **Manual, for risk**: a mistake would cost a lot and the checks could not catch it. A data model, an interface between components, or failure behavior qualifies. So does a path in the `station` that `## Critical` or `## Always review` lists.
3. **Manual, for practice**: under 15% of this project's orders made ready in the last two weeks are manual. `kitchen.zsh share` prints the count.
4. **Guided**: a call only the user can make is likely mid-work. Open design questions, unclear scope, no precedent in the repo, and an area where an earlier order in this project was parked each qualify.
5. **Auto** otherwise: a bug fix with a reproduction, a refactor whose behavior the tests pin, a mechanical change.

## The output

One line, sent with the approach:

    Mode: <mode>. <the reason, in a sentence>. Rule: <1 to 5, naming the `## Sorting` line for rule 1>.

## When the user overrides

When the user picks a mode other than the recommendation, log it before writing the order:

    kitchen.zsh order set <KEY> mode_override=@<file>

The file holds the recommended mode and its rule, the chosen mode, and the user's reason. Before recommending, read `kitchen.zsh overrides`, which prints this project's orders with a `mode_override` as `<KEY>  <text>`. When the same kind of override appears twice, propose a `## Sorting` rule to the user along with the recommendation.
