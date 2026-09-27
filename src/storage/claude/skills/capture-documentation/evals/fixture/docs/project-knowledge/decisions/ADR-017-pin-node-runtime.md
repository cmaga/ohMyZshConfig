---
type: decision
status: active
created: 2026-03-02
governs: [src/worker/index.js]
y_statement: In the context of the worker pool, facing runtime drift between hosts, we decided for a pinned Node LTS and neglected floating majors, to achieve reproducible claims, accepting a manual bump each LTS cycle.
approved_by: cmaga 2026-03-02
revisit_if: [code:`src/worker/index.js` claim loop changes, "external: Node LTS schedule moves, or the runtime is swapped", date:2030-01-01]
tracking: EN-17
---
# ADR-017: Pin the Node runtime

## Context

Two hosts ran different Node majors and the [[worker]] claim loop behaved
differently under load; [[ADR-001-use-postgres]] assumes one runtime.

## Decision

Pin the worker to the current Node LTS through the repo's version file.

## Considered options

- Pinned Node LTS (chosen) - one runtime everywhere; a bump is a reviewed change.
- Floating major - rejected: the drift this ADR exists to stop.
- Container-only runtime - rejected: the hosts are bare metal today; see [[ADR-018-bad-template-fields]] for the follow-up.

## Consequences

A manual bump each LTS cycle, tracked in the plan. The
[[constraint-single-writer-db]] guarantee is unaffected; the cache-layer
reopen sits in [[ADR-020-revisit-no-tripwire]].

## Objections considered

- Bumps will be forgotten - accepted as cost (see Consequences).
- Containers would solve this too - rejected: not on bare metal.
- Corepack could pin more - deferred: revisit if pnpm drift appears.

## Compliance

- Enforced by: test - `src/worker/index.js` [`claimNextJob`]
- Enforced by: review - the LTS bump checklist in the plan.
