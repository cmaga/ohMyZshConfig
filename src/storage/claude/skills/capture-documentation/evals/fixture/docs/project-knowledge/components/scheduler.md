---
type: component
status: active
created: 2026-03-10
---
# Scheduler

Runs the cron table and the retry backoff for [[worker]]; see
[[ADR-001-use-postgres]] for the queue it feeds. Field order is fixed; see
[[scheduler#Field order]].

## Cron parsing

Parses the five-field table in `src/worker/index.js` before each tick;
retries follow [[scheduler#Backoff policy]].

### Field order

Minute, hour, day, month, weekday.

## Backoff policy

Exponential backoff capped at one hour, implemented by `claimNextJob` in
`src/worker/index.js`; the reporting side reads `buildReport` from
`src/reporting/pipeline.js`.

## Reusable surface

- `buildReport` — `src/reporting/pipeline.js` — the report entry point the backoff policy schedules.
- `formatRow` (same file) — renders one report row.
- `claimNextJob` — `src/worker/index.js` — shared with [[worker]]; stays here.
