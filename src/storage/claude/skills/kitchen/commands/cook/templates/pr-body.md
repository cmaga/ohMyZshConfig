# PR body

The default PR description. A project replaces it with its own `.claude/kitchen/pr-body.md`. Copy the headings and replace each section's guidance with its text.

A reviewer with no code open reads it in a minute and knows what changes and why. Keep it under 2,000 characters, in plain words: no function, file, or path names and no commit hashes. A command a person runs, like `make test`, is fine. Drop a section with nothing to say.

## What and why

Two to four sentences: what changes, for whom, and why. Open with the order's intent.

## Approach

The solution chosen, in a sentence or two, and any alternative a reviewer would ask about, with why it lost.

## Proof

Screenshots or a video of a change a user sees, before and after. Otherwise how the behavior was checked and what it showed, in one or two sentences. A performance change gives one number with its unit, before and after.

## Questions for reviewers

One question per item, for the team. Leave the section out when there are none.
