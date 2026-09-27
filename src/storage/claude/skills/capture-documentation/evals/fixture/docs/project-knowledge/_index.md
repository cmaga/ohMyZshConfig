---
type: index
status: active
created: 2026-01-01
---
# Project knowledge index

## Overview

Entry point into the vault. Every bucket below is linked from here at
least once; two notes are deliberately left unlinked anywhere
(`plan/2026-q3-roadmap` and `research/research-warm-cache-spike`) to
exercise ORPHAN_NO_INBOUND, so do not add links to them here.

## Decisions

- [[decisions/ADR-001-use-postgres]]
- [[decisions/ADR-001-alt-name]]
- [[decisions/ADR-002-drop-legacy-queue]]
- [[decisions/ADR-004-retire-batch-job]]
- [[decisions/ADR-005-shrink-batch-window]]
- [[decisions/ADR-006-consolidate-queues]]
- [[decisions/ADR-007-cap-worker-concurrency]]
- [[decisions/ADR-008-switch-cache-layer]]
- [[decisions/ADR-009-scale-worker-pool]]
- [[decisions/ADR-010-amend-worker-timeout]]
- [[decisions/ADR-011-supersede-no-backlink]]
- [[decisions/ADR-012-successor-silent]]
- [[decisions/ADR-013-cycle-a]]
- [[decisions/ADR-014-cycle-b]]
- [[decisions/ADR-015-banner-mismatch]]
- [[ADR-017-pin-node-runtime]] - In the context of the worker pool, facing runtime drift between hosts, we decided for a pinned Node LTS and neglected floating majors, to achieve reproducible claims, accepting a manual bump each LTS cycle.
- [[ADR-018-bad-template-fields]] - Rebuild nightly for warm caches.
- [[ADR-020-revisit-no-tripwire]] - Keep the cache layer until a tripwire fires.

## Constraints
- [[constraints/constraint-retry-cap]]

- [[constraints/constraint-single-writer-db]]
- [[constraints/flatfee]]
- [[constraints/constraint-legacy-billing-freeze]]
- [[constraints/constraint-webhook-idempotency-keys]]

## Domain
- [[domain/domain-retry-policy]]

- [[domain/domain-credit-lifecycle]]
- [[domain/domain-bad-frontmatter]]
- [[domain/domain-marker-cases]]

## Architecture

- [[architecture/architecture-credit-deduction-flow]]
- [[architecture/architecture-payment-flow]]

## Components

- [[components/worker]]
- [[components/billing]]
- [[components/reporting-pipeline]]

## Policies

- [[policies/policy-data-retention]]
- [[policies/policy-incident-disclosure]]

## Customers

- [[customers/persona-enterprise-ops-lead]]
- [[customers/customer-selfserve-smb]]

## Plan

- [[plan/billing]]

## Research
- [[research/research-retry-survey]]

- [[research/research-message-queue-eval]]
- [[research/research-no-frontmatter]]
- [[research/research-unclosed-frontmatter]]
- [[research/research-inferred-no-sources]]
- [[research/research-sources-bad]]

## Misc

- [[misc/stray-note]]
