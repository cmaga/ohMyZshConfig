# Arena

Spawn N parallel candidates at the same task, pick a base, and graft the strongest parts of the losers into it. Use for "arena this", "throw it in the arena", or when one attempt at a non-trivial artifact would lock in the wrong shape.

Open the task list with one entry per phase (Frame, Fan out, Cross-judge, Pick, Graft, Verify) before launching anything.

## Phase A: Frame

Every candidate gets the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric, 3-6 concrete gradeable criteria for what success looks like on *this* task. It is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners. By default there are two, one on the judgment role and one on the other family role ([SKILL.md](../../../SKILL.md#subagents)); the caller can name others. The Claude models (opus, sonnet, haiku, fable) are one family, and `deepseek-flash-agent` is the other. A seat that cannot start runs on its role's fallback, and you say so. If dropped seats leave fewer than two runners, add runners until there are two, or one when the caller named one. Run each added runner on a remaining runner's model, or on the session model when none remain, and say so. Spawn more runners when the arena covers multiple design directions. Use the same model N times when the work is generation-bound rather than judgment-sensitive.
4. Give each candidate its own output location (`isolation: "worktree"` where the candidate writes into the repo, otherwise `arena-<slug>/candidate-<n>/` in the session's scratchpad directory), per the [separate before serializing shared state](../../../dependencies/principles/separate-before-serializing-shared-state.md) principle.

## Phase B: Fan out

Spawn all N agents in one message, each with the task, the path to the shared grounding, its own output path, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, spawn one judge whose brief says "do not edit files". The judge is never from the session's own family, as Phase A step 3 defines families. A session on a Claude model gets the other family role. A session on any other model gets the judgment role. When that judge cannot start, skip it, pick the base alone in Phase D, and say so; the other family role's Claude fallback does not judge, because it shares the session's family. If you do not know the session's model, use the other family role and say that the family check did not run. The judge sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale. It runs in parallel with your reading in Phase D. Don't spawn it while candidates are still writing.

## Phase D: Pick a base

Read every candidate end to end before picking. Score each against the rubric criterion by criterion, not on holistic feel, and compare with the cross-judge when Phase C ran one. Agreement on the base confirms the pick. Disagreement means one of you is biased or the rubric was ambiguous. Read both rationales before deciding.

Pick the base a future maintainer can extend most easily without breaking invariants. When two feel tied, prefer the cleaner boundary or smaller API, per the [laziness protocol](../../../dependencies/principles/laziness-protocol.md).

## Phase E: Graft

Walk each losing candidate once more for what is worth porting into the base, usually one or two things per candidate, not most of it. Fold each graft in by hand, per the [redesign from first principles](../../../dependencies/principles/redesign-from-first-principles.md) principle, so the result stays coherent under one mental model. Don't paste mechanically.

If the candidates converge on one shape, that is strong agreement. Note it and ship the consensus shape. No graft is needed. If they wildly diverge, Phase A was under-specified. Reframe and re-run rather than averaging the divergence.

## Phase F: Verify

Verify the synthesized artifact like any other output, per the [prove it works](../../../dependencies/principles/prove-it-works.md) principle. If verification finds a problem the arena missed, either Phase A was wrong (re-frame and re-run) or a candidate caught it and you missed the graft (go back to Phase E). Don't paper over it.

## Outputs

One synthesized artifact, with a short synthesis note alongside naming the base and why, the cross-judge's verdict or that Phase C skipped the judge, each graft with its source candidate, what was rejected and why, any convergence or dropouts, and the verification result.
