---
type: domain
status: active
created: 2026-09-20
conflicts_with: ["[[constraint-retry-cap]]"]
---
# Retry policy

> Status: CONTESTED with [[constraint-retry-cap]] on the retry ceiling

The [[worker]] retries a failed job five times before parking it; the
product team treats the fifth attempt as the customer-visible failure.
[[constraint-retry-cap]] holds the ceiling at three. The disagreement is
recorded here until the owners settle it; see the
[[domain-credit-lifecycle]] for what a parked job costs.
