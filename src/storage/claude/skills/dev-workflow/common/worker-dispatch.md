# Dispatch workers

- Spawn one `worker-agent` per task.
- Dispatch in waves from each card's **After** field: wave 1 is every card with `After: none`; dispatch a wave's cards in parallel, wait for it to finish, then dispatch the cards whose `After` blockers are now complete. Cards in the same wave must touch disjoint files — if two would collide, give one an `After` edge so they land in different waves.
- Each worker's prompt is the T-N task card from the plan — paste that block, not the whole plan. The worker can Read `.claude-artifacts/workflows/dev-workflow/plan.md` if it needs to disambiguate.
