---
type: decision
status: superseded
superseded_by: "[[ADR-012-successor-silent]]"
created: 2026-03-01
---
# ADR-011: Supersede the retry policy silently

> Status: SUPERSEDED by [[ADR-012-successor-silent]] — read that instead.

## Context

Related to the worker pool scaling in [[ADR-009-scale-worker-pool]] and the
original queue design in [[ADR-001-use-postgres]]. Superseded by
[[ADR-012-successor-silent]], which never links back here on purpose,
exercising SUPERSEDED_BY_NO_BACKLINK.

## Decision

Retire the eager retry policy in favor of the backoff policy
[[ADR-012-successor-silent]] introduces.

## Consequences

None beyond the missing-backlink finding this file exists to trigger.
