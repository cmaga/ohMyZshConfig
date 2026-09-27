---
type: constraint
status: active
severity: medium
created: 2026-09-21
governs: []
conflicts_with: ["[[domain-retry-policy]]"]
---
# Retry cap

> Status: CONTESTED with [[domain-retry-policy]] on the retry ceiling

No job is retried more than three times: the fourth failure parks it so
the [[worker]] pool cannot be pinned by one poison row. [[domain-retry-policy]]
records the product view of five attempts; both stay live until the
owners rule.
