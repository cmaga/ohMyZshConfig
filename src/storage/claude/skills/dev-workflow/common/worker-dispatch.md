# Dispatch workers

Workers arrive to a scaffolded repo with failing tests. Their job is to fill bodies until the tests pass — not to decide anything.

- Spawn one `worker-agent` per task, passing the card's model id verbatim as the `model` opt — `haiku`, `sonnet`, or `opus`, never an alias and never `fable` ([archetypes](../references/archetypes.md)). Record each `agentId`.
- Dispatch in waves from each card's **After** field: wave 1 is every card with `After: none`; dispatch a wave in parallel, wait, then dispatch the cards whose blockers are complete. Two cards in one wave touching the same file is a plan defect — fix the plan, then dispatch.
- Each worker's prompt is its T-N card from the plan — paste that block, not the whole plan. Every card says:
  - Workers may not run `git reset`, `checkout --`, `stash`, `clean`, or `restore`; each stages only its own files, by path. Workers in a wave share one tree.
  - The names of its concurrent siblings — a sibling's edits otherwise look like an intruder.
  - Commit in coherent pieces as you go.
  - *Anything you spawn reports to me, not to you; do the work yourself.*
  - A question reaches me only by ending your turn: return it with what you did and what a replacement would need.
- **Resume an escalating worker in preference to replacing it** — `SendMessage` your decision to its `agentId`. If the resume fails, replace it with the original card plus your decision plus its report; two failed resumes is the cap. Replace rather than resume when its context is spent — the branch is the handoff, not the transcript.
- A worker that reports a test it believes is wrong stops there. Read the test and the scaffold yourself, decide, then resume it with your decision — never tell it to work around the test.
