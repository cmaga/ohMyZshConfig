# Mode: who writes an order's code

Intake recommends a mode with the recipe and the review call, and the user approves or changes it.

## The three modes

| Mode     | Who writes the code                                                                                                              | Who starts it                                         | Can it ask the user |
| -------- | -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------- |
| `manual` | The user, starting from tests the contract station wrote first, which they may change. The session only looks things up for them | The user, with `/kitchen next manual` or `take <KEY>` | Yes                 |
| `guided` | A session, with the user there to answer                                                                                         | The user, with `/kitchen next guided` or `take <KEY>` | Yes                 |
| `auto`   | A session started by the scheduler, with nobody there                                                                            | The scheduler                                         | Never               |

## Which modes a project has

Not every project has every mode available to it. `kitchen.zsh modes` prints the ones this project has. Recommend only those, since `kitchen.zsh order set` refuses any other.

## Which recipes take which modes

- `manual` fits only recipes that ship code: feature, bug-fix, refactor, perf, and hillclimb.
- `enforce` and `change-a-skill` run only `guided`, whatever the project has unlocked.
- Every other recipe is `guided` or `auto`.
- A recipe that ships no code (investigation, prototype, eval, runtime-forensics, trace-forensics, multi-phase-plan) can always run `guided`, even where the project has not unlocked it, since no code of the line's lands.
- `catering` takes no mode. It runs with the user, and each deployment it files takes the project's highest unlocked mode.

## How to pick one

Go down this list and take the first rule that matches a mode the project has unlocked. Read the project rules first (`kitchen.zsh rules`), and the files you expect the order to touch.

1. **The project names one.** A line under `## Sorting` in the project rules gives a mode for this kind of ticket. That is the user's earlier call, so it wins.
2. **Manual, for risk.** A mistake would be expensive and the checks could not catch it: a data model, an interface between parts, or how something fails. Touching a file listed under `## Critical` or `## Always review` counts.
3. **Manual, for practice.** Under 15% of the orders made ready in this project in the last two weeks are manual (`kitchen.zsh share` prints the count). The user keeps their hand in the code.
4. **Guided, for open calls.** A call only the user can make is likely to come up while the work runs: an open design question, no precedent in the repo, or an area where an earlier order in this project was parked.
5. **Auto** otherwise: a bug fix with a reproduction, a refactor the tests pin down, a mechanical change.

## What to send

The mode and the reason in one sentence, such as "Guided, since nothing in the repo does this yet and the design will need your call." When rule 1 decided it, name the `## Sorting` line.

## When the user picks another mode

Before writing the order, log it: `kitchen.zsh order set <KEY> mode_override=@<file>`, the file holding the mode you recommended and why, the mode they chose, and their reason.

Before recommending, run `kitchen.zsh overrides`, which lists this project's logged overrides. When the user has made the same kind of override twice, propose a `## Sorting` line that makes it the rule, along with your recommendation.
