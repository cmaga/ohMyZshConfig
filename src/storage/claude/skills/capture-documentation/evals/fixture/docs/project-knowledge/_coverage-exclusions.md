---
type: exclusions
status: active
created: 2026-09-27
---
# Coverage exclusions

Population items the vault deliberately does not anchor. One entry per
line: a path glob or an exact symbol in backticks, then the reason.

- `src/vendor/**` - third-party code vendored in
- `legacyShim` - scheduled for deletion in EN-90
- `src/never/**` - nothing has lived here since the queue move
- `noReason`
