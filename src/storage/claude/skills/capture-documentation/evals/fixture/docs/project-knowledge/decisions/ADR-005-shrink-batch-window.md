---
type: decision
status: deprecated
created: 2026-01-20
owner: cmagana
---
# ADR-005: Shrink the batch draining window

This paragraph sits before the status banner on purpose, to exercise
BANNER_NOT_FIRST. The `owner` field above is not part of this bucket's
schema, exercising FIELD_UNKNOWN (suppressed via .vault-lint-exceptions).

> Status: DEPRECATED, see [[ADR-004-retire-batch-job]] instead.

## Context

Before batch draining was removed entirely (see
[[ADR-004-retire-batch-job]]), its window was shrunk as an intermediate
step.

## Decision

Shrink the nightly window from six hours to one.

## Consequences

Superseded in spirit by [[ADR-004-retire-batch-job]].
