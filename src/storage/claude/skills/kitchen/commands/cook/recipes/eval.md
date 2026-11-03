# Eval

Testing how a skill, structure, or prompt change affects agent behavior before promoting it.

**You own the experiment design. Plan, blind, run, synthesize.**

**Non-negotiables for blinding:**

- No `eval`, `test`, `judge`, `experiment`, `rubric`, `score`, `compare`, `benchmark`, `candidate`, or `arena` in any directory, file, or prompt the candidate sees.
- The candidate prompt looks like an organic user request. State the goal, not the meta.
- No chain-eliciting cues. Don't ask the candidate to list which skills, principles, or files they applied. Ask for design notes generally and grade chain-following from code shape, not self-report.
- Sanitize directory and slug names. Use project-shaped names a user might pick.
- Don't tell the candidate other candidates exist.
- The judge can know it's judging but sees outputs by sanitized label only, never by model name.
- Comparing two variants: one judge scores both sets in a single pass on one scale, blind to which set each came from.
- Candidates and the judge run with auto memory off: `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` in the environment of a headless `claude -p` run, or a fresh agent whose brief carries nothing from memory. A run that reads memory measures the memory, not the variant.

**Steps:**

1. **Frame.** State what variant is under test and what behavior counts as success. Write the rubric (3-6 concrete criteria) for the judge only. Hold it back from candidates.
2. **Set up sanitized environments.** Per-candidate working dir with the variant in place, under the session's scratchpad directory or in its own worktree. Plant any context an organic task would have: a project skeleton, the skills the candidate would naturally read.
3. **Author one organic prompt.** What a user would type. No leakage of what's being measured.
4. **Spawn N parallel candidates** on different models per the [arena](../stations/arena.md) station's Phase B. Each works in its own sanitized dir. Same prompt to each. Each subagent takes its role from [SKILL.md](../../../SKILL.md#subagents).
5. **Spawn one blinded judge** on the other family role per the arena station's Phase C. Judge sees outputs by sanitized label and the rubric, never a model name.
6. **Verify the chain from transcripts, not self-report.** Read each candidate's transcript in this workspace's folder, `~/.claude/projects/<slug>/`, where the slug is the workspace path with each `/` and `.` changed to `-`: a headless run's `<session>.jsonl`, or a subagent's under `<session>/subagents/`. Do not glob across `~/.claude/projects/*/`. That crosses workspace boundaries and reads private chats from unrelated projects. Look at which files each candidate actually opened. Grade chain-following from the files it really read plus the shape of the code, never from the candidate's own claims.
7. **Read every candidate output yourself** end to end. Compare to the judge's verdict. Disagreement means a model is biased or the rubric is ambiguous. Synthesize.

## Saved cases

A change to this skill is proven by running its saved cases in [dependencies/evals/](../../../dependencies/evals/) with the [skill-eval](../../../../skill-eval/SKILL.md) skill before the change is committed, never in pre-commit; a fix for something broken, per [SKILL.md](../../../SKILL.md#defects-and-lessons), skips them. These are real, billed runs, so the user starts them. A behavior a change adds or fixes gets a saved case of its own, written blind per the rules above, so a later change cannot quietly undo it.

**Reply:** variant under test, rubric, per-candidate notes, judge's verdict, your synthesis, and a recommendation for whether to promote the variant.
