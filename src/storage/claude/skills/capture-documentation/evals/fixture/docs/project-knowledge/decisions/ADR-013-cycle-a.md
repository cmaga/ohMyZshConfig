---
type: decision
status: superseded
superseded_by: "[[ADR-014-cycle-b]]"
created: 2026-03-03
---
# ADR-013: Batch writes ahead of the row-lock change

> Status: SUPERSEDED by [[ADR-014-cycle-b]] — read that instead.

## Context

Paired with [[ADR-014-cycle-b]] to exercise SUPERSESSION_CYCLE: each
supersedes the other. Predates the row-locking approach from
[[ADR-001-use-postgres]].

## Decision

Batch writes before committing, superseded by the row-lock change in
[[ADR-014-cycle-b]].

## Consequences

Row locks stay (until 2026-12-31 — see [[ADR-001-use-postgres]]).
