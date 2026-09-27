---
type: glossary
status: active
created: 2026-01-01
---
# Glossary

## Overview

Shared vocabulary for the fixture vault. See [[_index]] for the full
note index.

## Worker terms

### Retry budget

**Counted per job, not per worker.**

The number of attempts a job gets before it parks; see
[[constraints/constraint-retry-cap]].

### Backoff

Waiting longer between each attempt.

## Terms

- **Claim** - a worker taking ownership of a queued job row; see
  [[components/worker]].
- **Charge** - a billing operation that debits a customer; see
  [[components/billing]].
- **Credit** - a stored balance consumed over time; see
  [[domain/domain-credit-lifecycle]].

**Lease** - how long a worker holds a job before another may take it;
**never** renewed by a stale worker, see [[components/worker]].
