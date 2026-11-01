<!--
Catering's milestone plan (recipes/catering/plan.md, step 2).
Written to the order's worktree at .claude-artifacts/workflows/kitchen/<EPIC>-milestones.md.
scripts/plan-view.py renders it, and the session that files the orders reads each
M-N section by its markup, so keep every field below as written; prose inside a
section is free.
-->

# <EPIC>: milestones

Spec: `<path>` · Spec branch: `spec/<EPIC>`

## Decisions

<!-- One numbered line per call made while planning: the call, why, and what it
was chosen over. A call the code or the spec settled starts [ASSUMED]. The plan
view's narrative must cover every line. -->

1. <the call>. Why: <reason>. Rejected: <what it was chosen over>.

## Coverage

<!-- One row per part's Owns and per test scenario in the spec. A row with no
milestone is a plan defect. -->

| Spec item | Milestone |
| --------- | --------- |

## Checks today's code performs

<!-- From the gather. Every one keeps a fate on purpose. -->

| Check | Where | Fate (moved / adapted / retired: why) | Milestone |
| ----- | ----- | ------------------------------------- | --------- |

## Behavior in code the build deletes or rewrites

<!-- From the gather's sweep: one row per behavior, claimed or not. A leaving
file with no row is a plan defect. Omit the section when the sweep is empty. -->

| Behavior | Where | Fate (moved / adapted / retired: why) | Milestone |
| -------- | ----- | ------------------------------------- | --------- |

## M-1: <what becomes runnable>

**Proof:** `<one check that fails now and passes when this milestone is done. It
runs what ships: the real entry point on the settings a fresh install gets, over
data shaped like real use; doubles only at external boundaries>`

**Touches:** <the spec's part ids this milestone changes, such as C-2, C-4, X-1>

**After:** <none | M-1, M-2: the milestones it builds on>

**Review:** <yes | no: the user's pick; yes means its PR waits for their review>

**Recipe:** <feature | refactor | bug-fix | perf>

**Files:** `<path prefix>`, `<path prefix>` <the paths it owns: its order's station>

**Moves / adapts / new:** <from the gather; new code quotes the spec sentence
that forces it>

<What must be true when this milestone is done, and the Tests scenarios of its
parts that land in it.>

<!-- Repeat M-N per milestone. -->
