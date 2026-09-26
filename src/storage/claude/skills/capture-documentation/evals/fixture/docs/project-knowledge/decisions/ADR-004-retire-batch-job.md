---
type: decision
status: superseded
superseded_by: ADR-001-use-postgres
created: 2026-01-15
---
# ADR-004: Retire the nightly batch job

> Status: DEPRECATED, folded into the queue-based flow.

The nightly batch job that drained the legacy queue is gone now that
[[ADR-001-use-postgres]] handles claims continuously.

## Context

Batch draining raced with live traffic during business hours. This
continues the retirement started in [[ADR-002-drop-legacy-queue]].

## Decision

Delete the batch job; rely on [[worker]] claiming continuously instead.
