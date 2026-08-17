# Plan

Dispatch mechanics only. The design lives in the scaffold — do not re-describe it here.

Before writing the plan file, ensure `.claude-artifacts/` is gitignored for this repo. Idempotent — safe to re-run:

    F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"

Then write `.claude-artifacts/workflows/dev-workflow/plan.md` inside the worktree using [../templates/plan-template.md](../templates/plan-template.md) as the structure.

- Take `## Files` from the scaffold, not from guesses — the files already exist.
- Partition those files across task cards so that no two cards in the same wave touch the same file. Where two cards genuinely must touch one file — a module index, a DI registration, a barrel export — give the later one an `After` edge so they land in different waves. Ordering is decided here, not at dispatch.
- The boundaries are wrong only when no such ordering exists (the dependencies form a cycle) or the overlap is pervasive enough that the split is fiction. Then return to [scaffold](scaffold.md).
- Number outcomes (`O-1`, `O-2`, …). Each task card cites the outcome IDs it satisfies.
- Give every card a model, recorded on the card and chosen by [archetype](../references/archetypes.md): work a committed test verifies defaults to `MECHANICAL_WORKER_MODEL`, work needing judgment to `JUDGMENT_WORKER_MODEL`.
- Fill `## Reuse contract` from the [shape](shape.md) step's reuse lines and the `## Reusable surface` sections of vault component notes the plan touches.
- Carry each edge case that is only observable inside a body onto the card that owns that body.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`, then resolve it as described below.
- Mark a problem you find but are not folding in as `[DEFERRED: ... → ticket]` (related, too large) or `[REPORT: ...]` (unrelated), per the discovered-issue rule in [SKILL.md](../SKILL.md).

## Closing out the markers

Before the plan is done, grep it for `[NEEDS CLARIFICATION]`, `[DEFERRED]`, and `[REPORT]`. Nothing here stops for the user by default, attended or not.

- **A clarification you can settle from the code, you settle** — read what decides it, then rewrite the marker in place as `[ASSUMED: ...]` and carry it to the exit report. This is nearly all of them. The user cannot answer a question whose answer is in the repo, and asking spends their attention on something you were able to check.
- **Deferrals and reports** are left as they are and carried to the exit report. **Search Jira first** — per the discovered-issue rule in [SKILL.md](../SKILL.md), an existing ticket ends the matter and its key travels with the item. Never file one unasked.

The exception is a marker that is genuinely a strategic or directional call — which solution the product should offer, a trade-off only the user can price. That is an escalation, not a checkpoint: raise it, and expect it to be rare. Everything else you decide.

Nothing is left as prose. Every marker exits as `[ASSUMED]`, a ticket key, or a line in the exit report.
