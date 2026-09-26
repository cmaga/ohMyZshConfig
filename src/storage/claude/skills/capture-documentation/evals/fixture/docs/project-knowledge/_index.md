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

## Constraints

- [[constraints/constraint-single-writer-db]]
- [[constraints/flatfee]]
- [[constraints/constraint-legacy-billing-freeze]]
- [[constraints/constraint-webhook-idempotency-keys]]

## Domain

- [[domain/domain-credit-lifecycle]]
- [[domain/domain-bad-frontmatter]]

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

- [[research/research-message-queue-eval]]
- [[research/research-no-frontmatter]]
- [[research/research-unclosed-frontmatter]]

## Misc

- [[misc/stray-note]]
