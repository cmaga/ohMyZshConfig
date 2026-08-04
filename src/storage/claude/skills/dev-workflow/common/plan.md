# Plan

Before writing the plan file, ensure `.claude-artifacts/` is gitignored for this repo. Idempotent — safe to re-run:

    F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"

Then write `.claude-artifacts/workflows/dev-workflow/plan.md` inside the worktree using [../templates/plan-template.md](../templates/plan-template.md) as the structure.

The intent header (Objective, Outcomes, Out of scope, Autonomy, Stop rules) is the contract with workers. The mechanics (Files, Tasks, Tests) are the execution plan.

- Number outcomes (`O-1`, `O-2`, …). Each task card cites the outcome IDs it satisfies.
- Fill `## Reuse contract` from the Step-3 codebase-fit pass and the `## Reusable surface` sections of vault component notes the plan touches — workers don't discover reuse on their own.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`. Resolve each with the user as it's discovered — don't batch them up to the end.
- Mark a problem you find but are not folding in as `[DEFERRED: ... → ticket]` (related, too large) or `[REPORT: ...]` (unrelated), per the discovered-issue rule in [SKILL.md](../SKILL.md). Surface each at [plan presentation](plan-presentation.md) with your recommended routing and resolve before dispatch: name the existing ticket that already covers it, or ask the user whether to file one and write the key they approve. A deferral with no ticket key and no answer does not ship.
