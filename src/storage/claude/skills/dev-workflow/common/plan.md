# Plan

Before writing the plan file, ensure `.claude-artifacts/` is gitignored for this repo. Idempotent — safe to re-run:

    F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"

Then write `.claude-artifacts/workflows/dev-workflow/plan.md` inside the worktree using [../templates/plan-template.md](../templates/plan-template.md) as the structure.

The intent header (Objective, Outcomes, Out of scope, Autonomy, Stop rules) is the contract with workers. The mechanics (Files, Tasks, Tests) are the execution plan.

- Number outcomes (`O-1`, `O-2`, …). Each task card cites the outcome IDs it satisfies.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`. Resolve each with the user as it's discovered — don't batch them up to the end.
