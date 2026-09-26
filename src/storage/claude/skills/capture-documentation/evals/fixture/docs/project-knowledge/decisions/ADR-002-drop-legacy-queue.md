---
type: decision
status: superseded
created: 2026-01-10
---
# Legacy Queue Retirement

## Context

The legacy in-memory queue predated [[ADR-001-use-postgres]] and could not
survive a worker restart.

## Decision

Retire the legacy queue in favor of the Postgres-backed queue. A later,
narrower attempt at the same goal is documented in
[[ADR-005-shrink-batch-window]].

## Consequences

Superseded without a `superseded_by` field and without a status banner, and
its H1 does not start with "ADR-002:" -- all deliberate, for
SUPERSEDED_BY_REQUIRED, BANNER_MISSING, and ADR_TITLE_MISMATCH coverage.
