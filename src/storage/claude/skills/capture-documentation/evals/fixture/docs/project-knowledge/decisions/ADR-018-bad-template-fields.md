---
type: decision
status: active
created: 2026-03-03
governs: []
y_statement: We decided for a nightly rebuild, facing slow cold starts, in the context of the worker, to achieve warm caches, accepting a nightly window.
approved_by: Someone Approved It
---
# ADR-018: Bad template fields

## Context

Exists to exercise the ADR template v2 checks; pairs with
[[ADR-017-pin-node-runtime]].

## Decision

Rebuild nightly.

## Considered options

## Consequences

A nightly window.

## Objections considered

- The window collides with reporting - accepted as cost (see Consequences).
- Nobody asked for warm caches
