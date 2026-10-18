<!--
The milestone build's plan (common/milestone-build.md, Driver step 4).
Written to <tree>/.claude-artifacts/workflows/dev-workflow/milestones.md.
scripts/milestone-args.py reads each M-N section by its markup, so keep every
field below as written; prose inside a card is free.
-->

# <EPIC>: milestones

Spec: `<path>` · Integration branch: `spec/<EPIC>`

## Coverage

<!-- One row per part's Owns and per test scenario in the spec. A row with no
milestone is a plan defect. -->

| Spec item | Milestone |
| --------- | --------- |

## Checks today's code performs

<!-- From the gather. Every one keeps a fate on purpose. -->

| Check | Where | Fate (moved / adapted / retired: why) | Task |
| ----- | ----- | ------------------------------------- | ---- |

## Behavior in code the build deletes or rewrites

<!-- From the gather's sweep: one row per behavior, claimed or not. A leaving
file with no row is a plan defect. Omit the section when the sweep is empty. -->

| Behavior | Where | Fate (moved / adapted / retired: why) | Task |
| -------- | ----- | ------------------------------------- | ---- |

## M-1: <what becomes runnable>

**Proof:** `<one command that fails now and passes when this milestone is done.
It runs the real entry point on the settings a fresh install ships with, over
data shaped like real use; doubles only at external boundaries>`

**Touches:** <the spec's part ids this milestone changes, such as C-2, C-4, X-1>

**Pause:** <yes | no — the user's pick at approval>

**Scaffold:** <moves first, from → to, one commit each; then every new file,
signature, type, and schema the tasks fill, with bodies that raise>

**Tests:** <what the failing integration tests observe — the proof's behavior
and the edge cases this milestone owns>

### T-1.1: <title>

- **Files:** `<path>`, `<path>`
- **After:** none
- **Level:** <pinned | open | critical — by Levels in common/milestone-build.md>
- **Moves / adapts / new:** <from the gather; new code quotes the spec sentence
  that forces it>

<What must be true when this task is done, and the edge cases only observable
inside these bodies.>

<!-- Repeat T-N.N per task and M-N per milestone. -->
