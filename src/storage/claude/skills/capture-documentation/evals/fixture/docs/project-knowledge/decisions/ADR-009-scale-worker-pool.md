---
type: decision
status: active
created: 2026-02-01
---
# ADR-009: Scale the worker pool horizontally

## Context

Padded to exceed the note size hard limit at runtime, so run.sh can show
the `decisions` bucket's `size_limit: warn` schema override demoting
SIZE_NOTE_LIMIT to a warning here. In whole-vault mode every `_LIMIT`
finding is softened to warn regardless of bucket, so the contrast with
components/reporting-pipeline.md only shows up in the `changed` case,
where that file's growth past the hard limit is a new, unratcheted fail.
References [[ADR-001-use-postgres]] for the queue this pool drains.

## Decision

Run more worker processes against the same [[worker]] claim path.
Unrelated to the cache change in [[ADR-008-switch-cache-layer]], but
similar in spirit.

## Consequences

None beyond the size finding.
