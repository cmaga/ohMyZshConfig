# Calibrate: keep the verify skill accurate

`/kitchen taste calibrate` brings the project's verify skill (`.claude/skills/verify*/`) back in line with the app, per the [maintain a verification skill](../cook/stations/maintain-verification-skill.md) station. When the project has none, offer `/kitchen open` and stop.

Run it as written there, with two kitchen rules on top:

- A behavior the map describes that the app no longer does, and should, is a product regression. Report it to the user with its evidence, and file it as a ticket through the `ticket-provider` skill when they say to; never paper over it in the map.
- A `changed` outcome is one PR of proven corrections, opened through the [open a PR](../cook/recipes/open-a-pr.md) recipe's title and body rules. Its `## Proof` names each feature driven and what it showed.

**Reply:** the outcome (clean, changed, or blocked), the features covered live, each product regression with its evidence, each unreachable feature with what it lacks, and the PR link when there is one.
