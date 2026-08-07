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
- Fill `## Reuse contract` from the [shape](shape.md) gate's reuse lines and the `## Reusable surface` sections of vault component notes the plan touches.
- Carry each failure mode that is only observable inside a body onto the card that owns that body.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`. Resolve each with the user as it's discovered — don't batch them up to the end.
- Mark a problem you find but are not folding in as `[DEFERRED: ... → ticket]` (related, too large) or `[REPORT: ...]` (unrelated), per the discovered-issue rule in [SKILL.md](../SKILL.md).

## The plan is not finished while anything is open

Before the plan is done, grep it for `[NEEDS CLARIFICATION]`, `[DEFERRED]`, and `[REPORT]`. Every hit goes to the user with your recommended routing, and you wait.

- A clarification needs their answer written into the plan.
- A deferral or report needs the key of an existing ticket that already covers it, or their word to file a new one and the key you then wrote. **Search Jira before you propose either** — per the discovered-issue rule in [SKILL.md](../SKILL.md), an existing ticket ends the matter and you propose nothing.

A deferral with no ticket key and no answer does not ship. This is the only thing in planning that stops for the user — if the grep comes back empty, say nothing and carry on.
