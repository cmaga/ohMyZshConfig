---
type: constraint
status: active
created: 2026-01-11
severity: high
governs: []
---
# Single writer owns the claim path

## Context

Only one process may claim a queue row at a time; see
[[components/worker]] and [[decisions/ADR-001-use-postgres]].

## Reusable surface

- `claimNextJob` — `src/worker/index.js` — claims the next queued job row; also listed as the owning entry in components/worker.md, exercising SURFACE_DUPLICATE_HOME.
