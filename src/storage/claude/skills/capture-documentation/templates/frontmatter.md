# Frontmatter

Every note starts with YAML frontmatter:

```yaml
---
type: decision | constraint | domain | component | customer | plan | research | architecture | policy
status: active | superseded | proposed | open | closed
created: YYYY-MM-DD
---
```

## Per-type extras

- **Decision (ADR):** add `superseded_by: [[ADR-NNN-name]]` when applicable.
- **Constraint:** add `severity: blocking | high | medium | low`.
- **Policy:** add `steward:` (the role responsible for the policy — e.g. `founder` for a solo operation, or a named role like `head of engineering` / `CISO` once those exist; never a personal name) and `review_cadence:` (e.g. `annual`, `semi-annual`, `annual-or-on-material-change`).
