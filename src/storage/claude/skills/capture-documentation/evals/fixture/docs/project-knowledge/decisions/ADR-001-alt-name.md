---
type: decision
status: active
---
# ADR-001: Use Postgres for the job queue (duplicate number, for eval coverage)

## Context

Deliberately reuses ADR number 001 to exercise ADR_NUMBER_DUPLICATE, and
omits `created` to exercise FIELD_REQUIRED. See [[ADR-001-use-postgres]] for
the real decision this duplicates.

## Decision

Same decision as [[ADR-001-use-postgres]], different filename.

## Consequences

None beyond the duplicate-number and missing-field findings this file exists
to trigger.
