---
type: decision
status: active
basis: user-stated
sources: [ticket:STAX-12, pr:7, doc:src/worker/index.js]
governs: [src/nonexistent/**]
created: 2026-03-02
---
# ADR-012: Replace eager retry with backoff

## Context

Successor to [[ADR-001-use-postgres]]'s original queue design; also see
[[ADR-015-banner-mismatch]] for an unrelated banner-formatting fixture and
[[domain/domain-marker-cases]] for marker-extraction coverage. `governs`
above points at a path that does not exist, exercising GOVERNS_DEAD_GLOB.

## Decision

Switch [[worker]] from eager retry to exponential backoff.

## Consequences

The interim cap holds (until 2026-12-31 — pool resize pending).
