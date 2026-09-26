---
type: domain
type: domain
status: active
created: 2026-01-19
ref: [unclosed
---
# Domain note with malformed frontmatter

## Rules

The `type:` key above appears twice with the same value, exercising
FM_DUPLICATE_KEY without also causing a bucket mismatch. The `ref:` key
holds an unclosed bracket value, exercising FM_UNSUPPORTED_SYNTAX. Links to
[[components/worker]] to avoid also being an orphan.
