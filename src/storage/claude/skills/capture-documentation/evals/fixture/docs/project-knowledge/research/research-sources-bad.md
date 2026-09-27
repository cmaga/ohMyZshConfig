---
type: research
conflicts_with: worker
status: active
basis: guessed
sources: [ticket:stax-12, commit:0123456789abcdef0123456789abcdef01234567, doc:docs/missing.md, jira:1]
created: 2026-03-08
---
# Research: malformed source references

## Findings

Every entry in `sources` above is broken on purpose: a lowercase ticket id
(SOURCE_TICKET_PATTERN), a commit that does not resolve in this repo
(SOURCE_COMMIT_UNRESOLVED), a doc path that does not exist
(SOURCE_DOC_MISSING), and a prefix the schema does not recognize
(SOURCE_REF_FORMAT). `basis: guessed` is not a recognized value either,
exercising BASIS_ENUM. See [[ADR-001-use-postgres]] and
[[domain/domain-marker-cases]] for unrelated marker-extraction coverage.
Only the vault index links to this note on purpose, exercising
ORPHAN_HUB_ONLY_INBOUND (demoted to info by the research bucket's `orphan`
override).
