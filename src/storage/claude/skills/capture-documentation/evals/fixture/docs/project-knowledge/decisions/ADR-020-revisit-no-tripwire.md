---
type: decision
status: revisit
created: 2026-03-04
governs: []
---
# ADR-020: Revisit without a tripwire

## Context

A `status: revisit` decision that names no `revisit_if`; pairs with
[[ADR-017-pin-node-runtime]].

## Decision

Keep the cache layer until a tripwire fires.

## Consequences

Exercises ADR_REVISIT_IF_REQUIRED.
