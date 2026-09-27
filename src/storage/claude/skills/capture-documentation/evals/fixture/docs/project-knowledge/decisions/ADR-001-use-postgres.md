---
type: decision
status: active
governs: [src/worker/**]
created: 2026-01-05
---
# ADR-001: Use Postgres for the job queue

## Context

The worker pool needed a durable queue. See [[worker]] for the consumer side.

## Decision

Use a single Postgres table with `SELECT ... FOR UPDATE SKIP LOCKED` as the
job queue, claimed by [[worker]] via `claimNextJob`.

## Consequences

One writer owns the claim path; see [[constraint-single-writer-db]] for the
constraint this creates. This is unrelated to [[ADR-001-alt-name]], a
duplicate-numbered file kept for eval coverage.

Related follow-on decisions: [[ADR-006-consolidate-queues]] explores
per-tenant consolidation, [[ADR-007-cap-worker-concurrency]] revisits the
concurrency cap this enables removing, and [[ADR-009-scale-worker-pool]]
covers later scale-out.
