---
type: decision
status: superseded
superseded_by: "[[ADR-013-cycle-a]]"
governs: src/worker
created: 2026-03-04
---
# ADR-014: Row-lock the queue table

> Status: SUPERSEDED by [[ADR-013-cycle-a]] — read that instead.

## Context

Unrelated to the cache change in [[ADR-008-switch-cache-layer]]; paired
with [[ADR-013-cycle-a]] for SUPERSESSION_CYCLE coverage. `governs` above
is a bare string rather than a flow list, exercising GOVERNS_FORMAT.
Related to [[ADR-001-use-postgres]].

## Decision

Introduce `SELECT ... FOR UPDATE SKIP LOCKED`, later superseded back to
batching by [[ADR-013-cycle-a]].

## Consequences

None beyond the cycle and format findings this file exists to trigger.
