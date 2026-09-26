---
type: component
status: active
created: 2026-01-26
---
# Reporting pipeline

## Overview

Builds periodic reports from queue and billing activity. Stays a normal
size in the committed fixture; the `changed` case overlay grows this file
past the note size hard limit, and since components has no `size_limit`
override (unlike decisions/ADR-009) and no prior over-limit finding
exists at the baseline to ratchet against, that growth surfaces as a
genuine, unratcheted SIZE_NOTE_LIMIT fail rather than a softened warn.

## Reusable surface

- `buildReport` — `src/reporting/pipeline.js` — builds the periodic report.
