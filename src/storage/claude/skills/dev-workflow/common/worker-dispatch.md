# Dispatch workers

- Spawn one `worker-agent` per task.
- Run workers in parallel when their tasks touch disjoint files.
- Each worker's prompt is the T-N task card from the plan — paste that block, not the whole plan. The worker can Read `.claude-artifacts/workflows/dev-workflow/plan.md` if it needs to disambiguate.
