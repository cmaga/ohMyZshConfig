---
type: component
status: active
created: 2026-01-24
---
# Worker

## Overview

Claims and processes queue rows against the Postgres queue from
[[decisions/ADR-001-use-postgres]], subject to
[[constraints/constraint-single-writer-db]].

## Reusable surface

- `claimNextJob` — `src/worker/index.js` — claims the next queued job row; this is the SURFACE_DUPLICATE_HOME/SURFACE_REGION_CHANGED demonstration entry, also listed in constraints/constraint-single-writer-db.md.
- `processQueueItem` — `src/worker/index.js` — processes one claimed job row.
