---
type: constraint
status: superseded
superseded_by: "[[ADR-001-use-postgres]]"
created: 2026-01-30
---
# ADR-007: Cap worker concurrency at one process

> Status: SUPERSEDED, replaced by wider queue changes.

## Context

Concurrency was capped at one process before [[ADR-001-use-postgres]]
introduced row-level locking.

## Decision

Remove the cap now that `SELECT ... FOR UPDATE SKIP LOCKED` makes it safe
for [[worker]] to run with more than one process.

## Consequences

The `type` field above says "constraint" instead of "decision", exercising
TYPE_BUCKET_MISMATCH; the SUPERSEDED banner above names no link target,
exercising BANNER_NO_LINK.
