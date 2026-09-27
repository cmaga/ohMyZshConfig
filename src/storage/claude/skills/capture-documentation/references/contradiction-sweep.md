# Contradiction sweep

A manual, whole-vault pass for claims that disagree. The write path
(SKILL.md step 11d) probes only the notes a change touches; this sweep
covers the rest. Run it on request, never on a schedule.

1. Candidates: `bash $S/probe-pairs.sh $ROOT/docs/project-knowledge $(cd $ROOT/docs/project-knowledge && ls */*.md)` prints every pair (`NOTE<TAB>OTHER<TAB>reason`). Drop pairs where either side is a hub or a tombstone; keep the rest.
2. Judge: for each pair dispatch one read-only haiku subagent with both notes' overlapping sections (by line range, not whole notes) and this ask: return `{"conflict": bool, "axis": "<one phrase>", "evidence": ["a:line", "b:line"]}`; a conflict is two live sentences that cannot both be true, not two notes about the same thing. Restated facts, different detail levels and one note deferring to the other are not conflicts.
3. Triage the `conflict: true` rows yourself, reading the cited lines: a code claim is settled by the code (the wrong side is drift, brief the scribe per step 10); an intent claim goes to the human as `Contested: <a> and <b> disagree on <axis>` with the two cited lines.
4. Record what the human rules harmless as `_fragments/rulings/YYYY-MM-DD-<a>--<b>.md` (`kind: ruling`, `at`, `ref`, one sentence naming both `[[notes]]`); the pair never surfaces again. Record what stays open with `conflicts_with` and the CONTESTED banner on both sides.

Cost: one haiku call per pair; engine produces about 900 pairs, most of them `links`, so filter to `shares` and `surface` reasons first when the budget is tight.
