# Dispatch workers

Workers arrive to a scaffolded repo with failing tests. Their job is to fill bodies until the tests pass — not to decide anything.

- Spawn one `worker-agent` per task, passing the card's model id verbatim as the `model` opt — `haiku`, `sonnet`, `opus`, or `fable`, never an archetype or alias name. Record each worker's `agentId` from its spawn result.
- Dispatch in waves from each card's **After** field: wave 1 is every card with `After: none`; dispatch a wave's cards in parallel, wait for it to finish, then dispatch the cards whose `After` blockers are now complete. Cards in the same wave must touch disjoint files — if two would collide, give one an `After` edge so they land in different waves.
- Each worker's prompt is the T-N task card from the plan — paste that block, not the whole plan. The worker can Read `.claude-artifacts/workflows/dev-workflow/plan.md` if it needs to disambiguate.
- **Resume an escalating worker, never replace it.** When a worker stops and escalates, send your decision to its `agentId` with `SendMessage`. It keeps every file it read and every decision it made; a fresh worker re-reads all of it and re-derives state you already paid for.
- A worker that reports a test it believes is wrong stops there. Read the test and the scaffold yourself, decide, then resume that worker with your decision — never tell it to work around the test.
