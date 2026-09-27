---
type: decision
status: superseded
superseded_by: "[[ADR-012-successor-silent]]"
created: 2026-03-05
---
# ADR-015: Switch the backoff base delay

> Status: SUPERSEDED by [[ADR-009-scale-worker-pool]] — read that instead.

## Context

`superseded_by` above points at [[ADR-012-successor-silent]], but the
banner names [[ADR-009-scale-worker-pool]] instead, exercising
BANNER_SUCCESSOR_MISMATCH. Related to [[ADR-001-use-postgres]].

## Decision

Fold into the backoff policy [[ADR-012-successor-silent]] introduces.

## Consequences

None beyond the banner-mismatch finding this file exists to trigger.
