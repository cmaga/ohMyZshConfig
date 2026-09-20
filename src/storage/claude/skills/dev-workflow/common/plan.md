# Plan

Dispatch mechanics only. The design lives in the scaffold.

Ensure `.claude-artifacts/` is gitignored for this repo (idempotent):

    F="$(git rev-parse --git-common-dir)/info/exclude"; grep -qxF '.claude-artifacts/' "$F" || echo '.claude-artifacts/' >> "$F"

Then write `.claude-artifacts/workflows/dev-workflow/plan.md` inside the worktree from [../templates/plan-template.md](../templates/plan-template.md).

- Take `## Files` from the scaffold — the files already exist.
- Partition those files across task cards so no two cards in the same wave touch the same file. Where two must — a module index, a barrel export — give the later one an `After` edge. The boundaries are wrong only when no ordering exists or the overlap is pervasive; then return to [scaffold](scaffold.md).
- Number outcomes (`O-1`, `O-2`, …). Each card cites the outcome IDs it satisfies.
- Give every card a model by [archetype](../references/archetypes.md): test-verified work defaults to `MECHANICAL_WORKER_MODEL`, judgment work to `JUDGMENT_WORKER_MODEL`.
- Fill `## Reuse contract` from Step 4.2's reuse mapping and the `## Reusable surface` sections of vault notes the plan touches.
- Carry each edge case only observable inside a body onto the card that owns that body.
- Mark unresolved ambiguity inline as `[NEEDS CLARIFICATION: ...]`. Mark `[DEFERRED: ... → ticket]` or `[REPORT: ...]` only when a fix genuinely cannot ride this branch, with the reason in the marker — "out of scope" is not one.

## Closing out the markers

Grep the plan for `[NEEDS CLARIFICATION]`, `[DEFERRED]`, and `[REPORT]`. Nothing here stops for the user by default.

- **A clarification you can settle from the code, you settle** — rewrite it in place as `[ASSUMED: ...]` and carry it to the exit report. This is nearly all of them.
- **Deferrals and reports** go to the [loose-end tracker](exit.md#the-loose-end-tracker) after the Jira search in [SKILL.md](../SKILL.md). Never file one unasked.
- A marker that is genuinely a strategic call — which solution the product should offer — is an escalation, and rare.

Every marker exits as `[ASSUMED]`, a ticket key, or an open task the user answers.
